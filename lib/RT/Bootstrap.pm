# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}
use warnings;
use strict;

package RT::Bootstrap;
use base qw/Jifty::Bootstrap/;

sub run {
    my $self = shift;
    $self->insert_initial_data();
    $self->insert_data( $RT::EtcPath . "/initialdata" );
}

use File::Spec;

sub _yesno {

    #print "Proceed [y/N]:";
    my $x = scalar(<STDIN>);
    $x =~ /^y/i;
}

sub insert_acl { }

=head2 insert_initial_data

=cut

sub insert_initial_data {
    my $self = shift;

    require RT::CurrentUser;
    my $bootstrap_user = RT::CurrentUser->new( _bootstrap => 1 );

    # create RT_System user and grant him rights
    {
        my $test_user =
          RT::Model::User->new( current_user => $bootstrap_user );
        $test_user->load('RT_System');
        if ( $test_user->id ) {

            #            push @warns, "Found system user in the DB.";
        }
        else {
            my $user = RT::Model::User->new( current_user => $bootstrap_user );
            my ( $val, $msg ) = $user->_bootstrap_create(
                name      => 'RT_System',
                real_name => 'The RT System itself',
                comments  => 'Do not delete or modify this user. '
                  . 'It is integral to RT\'s internal database structures',
            );
            return ( $val, $msg ) unless $val;
        }
    }

    Jifty::DBI::Record::Cachable->flush_cache;

    # grant SuperUser right to system user
    {
        my $test_ace = RT::Model::ACE->new( current_user => RT->system_user );
        if ( $test_ace->id ) {

            #            push @warns, "System user has global SuperUser right.";
        }
        else {
            my $ace = RT::Model::ACE->new( current_user => RT->system_user );
            my ( $val, $msg ) = $ace->_bootstrap_create(
                principal_id   => acl_equiv_group_id( RT->system_user ),
                principal_type => 'Group',
                right_name     => 'SuperUser',
                object_type    => 'RT::System',
                object_id      => 1,
            );
            return ( $val, $msg ) unless $val;
        }
    }

    Jifty::DBI::Record::Cachable->flush_cache;

    # system groups
    foreach my $name (qw(Everyone Privileged Unprivileged)) {
        my $group = RT::Model::Group->new( current_user => RT->system_user );
        $group->load_system_internal_group($name);
        if ( $group->id ) {

            #            push @warns, "System group '$name' already exists.";
            next;
        }

        $group = RT::Model::Group->new( current_user => RT->system_user );
        my ( $val, $msg ) = $group->_create(
            type        => $name,
            domain      => 'SystemInternal',
            description => 'Pseudogroup for internal use',    # loc
            name        => '',
            instance    => '',
        );
        return ( $val, $msg ) unless $val;
    }

    # nobody
    {
        my $user = RT::Model::User->new( current_user => RT->system_user );
        $user->load('Nobody');
        if ( $user->id ) {

            #            push @warns, "Found 'Nobody' user in the DB.";
        }
        else {
            my ( $val, $msg ) = $user->create(
                name      => 'Nobody',
                real_name => 'Nobody in particular',
                comments => 'Do not delete or modify this user. It is integral '
                  . 'to RT\'s internal data structures',
                privileged => 0,
            );
            return ( $val, $msg ) unless $val;
        }

        if ( $user->has_right( right => 'OwnTicket', object => RT->system ) ) {

          #            push @warns, "User 'Nobody' has global OwnTicket right.";
        }
        else {
            my ( $val, $msg ) = $user->principal_object->grant_right(
                right  => 'OwnTicket',
                object => RT->system,
            );
            return ( $val, $msg ) unless $val;
        }
    }

    # rerun to get init Nobody as well
    RT::init_system_objects();

    # system role groups
    foreach my $name (qw(owner requestor cc admin_cc)) {
        my $group = RT::Model::Group->new( current_user => RT->system_user );
        $group->load_system_role_group($name);
        if ( $group->id ) {

            #            push @warns, "System role '$name' already exists.";
            next;
        }

        $group = RT::Model::Group->new( current_user => RT->system_user );
        my ( $val, $msg ) = $group->_create(
            type        => $name,
            domain      => 'RT::System-Role',
            description => 'SystemRolegroup for internal use',    # loc
            name        => '',
            instance    => '',
        );
        return ( $val, $msg ) unless $val;
    }
}

=head insert_data

=cut

# load some sort of data into the database
sub insert_data {
    my $self     = shift;
    my $datafile = shift;

    # Slurp in stuff to insert from the datafile. Possible things to go in here:-
    our ( @Groups, @Users, @ACL, @Queues, @scrip_actions, @scrip_conditions, @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final );
    local ( @Groups, @Users, @ACL, @Queues, @scrip_actions, @scrip_conditions, @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final );

    require $datafile
        || die "Couldn't find initial data for import\n" . $@;

    if (@Initial) {

        #print "Running initial actions...\n";
        # Don't trap errors here, as they *should* be fatal
        $_->() for @Initial;
    }
    if (@Groups) {

        #print "Creating groups...";
        #print "My systemuser is ".RT->system_user ."\n";
        foreach my $item (@Groups) {
            my $new_entry = RT::Model::Group->new( current_user => RT->system_user );
            my $member_of = delete $item->{'member_of'};
            my ( $return, $msg ) = $new_entry->_create(%$item);

            #print "(Error: $msg)" unless $return;
            #print $return. ".";
            if ($member_of) {
                $member_of = [$member_of] unless ref $member_of eq 'ARRAY';
                foreach (@$member_of) {
                    my $parent = RT::Model::Group->new( current_user => RT->system_user );
                    if ( ref $_ eq 'HASH' ) {
                        $parent->load_by_cols(%$_);
                    } elsif ( !ref $_ ) {
                        $parent->load_user_defined_group($_);
                    } else {
                        print "(Error: wrong format of member_of field."
                            . " Should be name of user defined group or"
                            . " hash reference with 'column => value' pairs."
                            . " Use array reference to add to multiple groups)";
                        next;
                    }
                    unless ( $parent->id ) {
                        print "(Error: couldn't load group to add member)";
                        next;
                    }
                    my ( $return, $msg ) = $parent->add_member( $new_entry->id );

                    #print "(Error: $msg)" unless ($return);
                    #print $return. ".";
                }
            }
        }

        #print "done.\n";
    }
    if (@Users) {

        #print "Creating users...";
        foreach my $item (@Users) {
            my $new_entry = RT::Model::User->new( current_user => RT->system_user );
            my ( $return, $msg ) = $new_entry->create(%$item);
            print "(Error: $msg)" unless $return;

            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@Queues) {

        #print "Creating queues...";
        for my $item (@Queues) {
            my $new_entry = RT::Model::Queue->new( current_user => RT->system_user );
            my ( $return, $msg ) = $new_entry->create(%$item);

            #print "(Error: $msg)" unless $return;
            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@CustomFields) {

        #print "Creating custom fields...";
        for my $item (@CustomFields) {
            my $new_entry = RT::Model::CustomField->new( current_user => RT->system_user );
            my $values = delete $item->{'values'};

            my @queues;

            # if ref then it's list of queues, so we do things ourself
            if ( exists $item->{'queue'} && ref $item->{'queue'} ) {
                $item->{'lookup_type'} = 'RT::Model::Queue-RT::Model::Ticket';
                @queues = @{ delete $item->{'queue'} };
            }

            my ( $return, $msg ) = $new_entry->create(%$item);
            unless ($return) {

                #print "(Error: $msg)\n";
                next;
            }

            foreach my $value ( @{$values} ) {
                my ( $return, $msg ) = $new_entry->add_value(%$value);

                #print "(Error: $msg)\n" unless $return;
            }

            # apply by default
            if ( !@queues && !exists $item->{'queue'} && $item->{lookup_type} ) {
                my $ocf = RT::Model::ObjectCustomField->new( current_user => RT->system_user );
                $ocf->create( custom_field => $new_entry->id );
            }

            for my $q (@queues) {
                my $q_obj = RT::Model::Queue->new( current_user => RT->system_user );
                $q_obj->load($q);
                unless ( $q_obj->id ) {

                    #print "(Error: Could not find queue " . $q . ")\n";
                    next;
                }
                my $OCF = RT::Model::ObjectCustomField->new( current_user => RT->system_user );
                ( $return, $msg ) = $OCF->create(
                    custom_field => $new_entry->id,
                    object_id    => $q_obj->id,
                );

                #print "(Error: $msg)\n" unless $return and $OCF->id;
            }

            #print $new_entry->id. ".";
        }

        #print "done.\n";
    }
    if (@ACL) {

        #print "Creating ACL...";
        for my $item (@ACL) {
            my ( $princ, $object );

            # Global rights or queue rights?
            if ( $item->{'CF'} ) {
                $object = RT::Model::CustomField->new( current_user => RT->system_user );
                my @columns = ( name => $item->{'CF'} );
                push @columns, queue => $item->{'queue'}
                    if $item->{'queue'} and not ref $item->{'queue'};
                $object->load_by_name(@columns);
            } elsif ( $item->{'queue'} ) {
                $object = RT::Model::Queue->new( current_user => RT->system_user );
                $object->load( $item->{'queue'} );
            } else {
                $object = RT->system;
            }

            #print "Couldn't load object" and next unless $object and $object->id;

            # Group rights or user rights?
            if ( $item->{'GroupDomain'} ) {
                $princ = RT::Model::Group->new( current_user => RT->system_user );
                if ( $item->{'GroupDomain'} eq 'UserDefined' ) {
                    $princ->load_user_defined_group( $item->{'group_id'} );
                } elsif ( $item->{'GroupDomain'} eq 'SystemInternal' ) {
                    $princ->load_system_internal_group( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::System-Role' ) {
                    $princ->load_system_role_group( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::Model::Queue-Role'
                    && $item->{'queue'} )
                {
                    $princ->load_queue_role_group(
                        type  => $item->{'GroupType'},
                        queue => $object->id
                    );
                } else {
                    $princ->load( $item->{'group_id'} );
                }
            } else {
                $princ = RT::Model::User->new( current_user => RT->system_user );
                $princ->load( $item->{'user_id'} );
            }

            unless ( $princ->id ) {
                Carp::confess( "Could not create principal! - " . YAML::Dump($item) );
            }

            # Grant it
            my ( $return, $msg ) = $princ->principal_object->grant_right(
                right  => $item->{'right'},
                object => $object
            );

            if ($return) {

                #warn $return. ".";
            } else {

                #warn $msg . ".";

            }

        }

        #print "done.\n";
    }

    if (@scrip_actions) {

        #print "Creating scrip_actions...";

        for my $item (@scrip_actions) {
            my $new_entry = RT::Model::ScripAction->new( current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }

    if (@scrip_conditions) {

        #print "Creating scrip_conditions...";

        for my $item (@scrip_conditions) {
            my $new_entry = RT::Model::ScripCondition->new( current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }

    if (@Templates) {

        #print "Creating templates...";

        for my $item (@Templates) {
            my $new_entry = RT::Model::Template->new( current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@Scrips) {

        #print "Creating scrips...";

        for my $item (@Scrips) {
            my $new_entry = RT::Model::Scrip->new( current_user => RT->system_user );

            my @queues
                = ref $item->{'queue'} eq 'ARRAY'
                ? @{ $item->{'queue'} }
                : $item->{'queue'} || 0;
            push @queues, 0 unless @queues;    # add global queue at least

            foreach my $q (@queues) {
                my ( $return, $msg ) = $new_entry->create( %$item, queue => $q );
                if ($return) {

                    #print $return. ".";
                } else {

                    #print "(Error: $msg)\n";
                }
            }
        }

        #print "done.\n";
    }

    if (@Attributes) {

        #print "Creating predefined searches...";

        use RT::System;
        my $sys = RT::System->new( current_user => RT->system_user );
        for my $item (@Attributes) {
            my $obj = delete $item->{object};    # XXX: make this something loadable
            $obj ||= $sys;
            my ( $return, $msg ) = $obj->add_attribute(%$item);
            if ($return) {

                #print $return. ".";
            } else {

                #print "(Error: $msg)\n";
            }
        }

        #print "done.\n";
    }
    if (@Final) {

        #print "Running final actions...\n";
        for (@Final) {
            eval { $_->(); };
            print "(Error: $@)\n" if $@;
        }
    }

    my $db_type = RT->config->get('DatabaseType');

    #print "Done setting up database content.\n";
}

=head2 acl_equiv_group_id

Given a userid, return that user's acl equivalence group

=cut

sub acl_equiv_group_id {
    my $username = shift;
    my $user = RT::Model::User->new( current_user => RT->system_user );
    $user->load($username);
    my $equiv_group = RT::Model::Group->new( current_user => RT->system_user );
    $equiv_group->load_acl_equivalence_group($user);
    return ( $equiv_group->id );
}

1;
