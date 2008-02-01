use warnings;
use strict;

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
# {{{ Front Material

=head1 SYNOPSIS

  use RT::Model::Ticket;
  my $ticket = RT::Model::Ticket->new($CurrentUser);
  $ticket->load($ticket_id);

=head1 description

This module lets you manipulate RT\'s ticket object.


=head1 METHODS


=cut

package RT::Model::Ticket;

use strict;
no warnings qw(redefine);
use base qw/RT::Record/;

sub table {'Tickets'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

    column effective_id => max_length is 11, type is 'int(11)', default is '0';
    column queue       => max_length is 11, type is 'int(11)', default is '0';
    column type => max_length is 16, type is 'varchar(16)', default is '';
    column issue_statement => max_length is 11,
        type is 'int(11)', default is '0';
    column Resolution => max_length is 11, type is 'int(11)', default is '0';
    column owner      => max_length is 11, type is 'int(11)', default is '0';
    column subject => max_length is 200, type is 'varchar(200)', default is '';
    column initial_priority => max_length is 11, type is 'int(11)', default is '0';
    column final_priority => max_length is 11, type is 'int(11)', default is '0';
    column priority => max_length is 11, type is 'int(11)', default is '0';
    column
        time_estimated => max_length is 11,
        type is 'int(11)', default is '0';
    column time_worked => max_length is 11, type is 'int(11)', default is '0';
    column status => max_length is 10, type is 'varchar(10)', default is '';
    column time_left => max_length is 11, type is 'int(11)', default is '0';
    column told     => type is 'datetime', default is '';
    column starts   => type is 'datetime', default is '';
    column started  => type is 'datetime', default is '';
    column due      => type is 'datetime', default is '';
    column resolved => type is 'datetime', default is '';
    column
        last_updated_by => max_length is 11,
        type is 'int(11)', default is '0';
    column last_updated => type is 'datetime', default is '';
    column creator => max_length is 11,   type is 'int(11)', default is '0';
    column created => type is 'datetime', default is '';
    column disabled => max_length is 6, type is 'smallint(6)', default is '0';
};

use RT::Model::Queue;
use RT::Model::User;
use RT::Record;
use RT::Model::LinkCollection;
use RT::Date;
use RT::Model::CustomFieldCollection;
use RT::Model::TicketCollection;
use RT::Model::TransactionCollection;
use RT::Reminders;
use RT::URI::fsck_com_rt;
use RT::URI;
use MIME::Entity;

# {{{ LINKTYPEMAP
# A helper table for links mapping to make it easier
# to build and parse links between tickets

our %LINKTYPEMAP = (
    MemberOf => {
        type => 'MemberOf',
        Mode => 'target',
    },
    Parents => {
        type => 'MemberOf',
        Mode => 'target',
    },
    Members => {
        type => 'MemberOf',
        Mode => 'base',
    },
    Children => {
        type => 'MemberOf',
        Mode => 'base',
    },
    has_member => {
        type => 'MemberOf',
        Mode => 'base',
    },
    RefersTo => {
        type => 'RefersTo',
        Mode => 'target',
    },
    ReferredToBy => {
        type => 'RefersTo',
        Mode => 'base',
    },
    DependsOn => {
        type => 'DependsOn',
        Mode => 'target',
    },
    DependedOnBy => {
        type => 'DependsOn',
        Mode => 'base',
    },
    MergedInto => {
        type => 'MergedInto',
        Mode => 'target',
    },

);

# }}}

# {{{ LINKDIRMAP
# A helper table for links mapping to make it easier
# to build and parse links between tickets

our %LINKDIRMAP = (
    MemberOf => {
        base   => 'MemberOf',
        target => 'has_member',
    },
    RefersTo => {
        base   => 'RefersTo',
        target => 'ReferredToBy',
    },
    DependsOn => {
        base   => 'DependsOn',
        target => 'DependedOnBy',
    },
    MergedInto => {
        base   => 'MergedInto',
        target => 'MergedInto',
    },

);

# }}}

sub LINKTYPEMAP { return \%LINKTYPEMAP }
sub LINKDIRMAP  { return \%LINKDIRMAP }

# {{{ sub load

=head2 Load

Takes a single argument. This can be a ticket id, ticket alias or 
local ticket uri.  If the ticket can't be loaded, returns undef.
Otherwise, returns the ticket id.

=cut

sub load {
    my $self = shift;
    my $id = shift || '';

#TODO modify this routine to look at effective_id and do the recursive load
# thing. be careful to cache all the interim tickets we try so we don't loop forever.

    # FIXME: there is no Ticketbase_uri option in config
    my $base_uri = RT->config->get('Ticketbase_uri') || '';

    #If it's a local URI, turn it into a ticket id
    if ( $base_uri && $id =~ /^$base_uri(\d+)$/ ) {
        $id = $1;
    }

    #If it's a remote URI, we're going to punt for now
    elsif ( $id =~ '://' ) {
        return (undef);
    }

    #If we have an integer URI, load the ticket
    if ( defined $id && $id =~ /^\d+$/ ) {
        my ( $ticketid, $msg ) = $self->load_by_id($id);

        unless ( $self->id ) {
            Jifty->log->fatal("$self tried to load a bogus ticket: $id\n");
            return (undef);
        }
    }

    #It's not a URI. It's not a numerical ticket ID. Punt!
    else {
        Jifty->log->warn("Tried to load a bogus ticket id: '$id'");
        return (undef);
    }

    #If we're merged, resolve the merge.
    if ( ( $self->effective_id ) and ( $self->effective_id != $self->id ) ) {
        Jifty->log->debug( "We found a merged ticket."
                . $self->id . "/"
                . $self->effective_id );
        return ( $self->load( $self->effective_id ) );
    }

    #Ok. we're loaded. lets get outa here.
    return ( $self->id );

}

# }}}

# {{{ sub loadByURI

=head2 LoadByURI

Given a local ticket URI, loads the specified ticket.

=cut

sub load_by_uri {
    my $self = shift;
    my $uri  = shift;

    # FIXME: there is no Ticketbase_uri option in config
    my $base_uri = RT->config->get('Ticketbase_uri');
    if ( $base_uri && $uri =~ /^$base_uri(\d+)$/ ) {
        my $id = $1;
        return $self->load($id);
    } else {
        return undef;
    }
}

# }}}

# {{{ sub create

=head2 Create (ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  id 
  queue  - Either a queue object or a queue name
  Requestor -  A reference to a list of  email addresses or RT user names
  Cc  - A reference to a list of  email addresses or names
  AdminCc  - A reference to a  list of  email addresses or names
  type -- The ticket\'s type. ignore this for now
  owner -- This ticket\'s owner. either an RT::Model::User object or this user\'s id
  subject -- A string describing the subject of the ticket
  priority -- an integer from 0 to 99
  initial_priority -- an integer from 0 to 99
  final_priority -- an integer from 0 to 99
  status -- any valid status (Defined in RT::Model::Queue)
  time_estimated -- an integer. estimated time for this task in minutes
  time_worked -- an integer. time worked so far in minutes
  time_left -- an integer. time remaining in minutes
  starts -- an ISO date describing the ticket\'s start date and time in GMT
  due -- an ISO date describing the ticket\'s due date and time in GMT
  mime_obj -- a MIME::Entity object with the content of the initial ticket request.
  custom_field-<n> -- a scalar or array of values for the customfield with the id <n>

Ticket links can be set up during create by passing the link type as a hask key and
the ticket id to be linked to as a value (or a URI when linking to other objects).
Multiple links of the same type can be created by passing an array ref. For example:

  Parent => 45,
  DependsOn => [ 15, 22 ],
  RefersTo => 'http://www.bestpractical.com',

Supported link types are C<MemberOf>, C<has_member>, C<RefersTo>, C<ReferredToBy>,
C<DependsOn> and C<DependedOnBy>. Also, C<Parents> is alias for C<MemberOf> and
C<Members> and C<Children> are aliases for C<has_member>.

Returns: TICKETID, Transaction object, Error Message


=cut

sub create {
    my $self = shift;

    my %args = (
        id                  => undef,
        effective_id         => undef,
        queue               => undef,
        Requestor           => undef,
        Cc                  => undef,
        AdminCc             => undef,
        type                => 'ticket',
        owner               => undef,
        subject             => '',
        initial_priority    => undef,
        final_priority      => undef,
        priority            => undef,
        status              => 'new',
        time_worked         => "0",
        time_left           => 0,
        time_estimated      => 0,
        due                 => undef,
        starts              => undef,
        started             => undef,
        resolved            => undef,
        mime_obj             => undef,
        _record_transaction => 1,
        dry_run              => 0,
        @_
    );

    my ( $ErrStr, @non_fatal_errors );

    my $queue_obj = RT::Model::Queue->new( current_user => RT->system_user );
    if ( ref $args{'queue'} && $args{'queue'}->isa('RT::Model::Queue') ) {
        $queue_obj->load( $args{'queue'}->id );
    } elsif ( $args{'queue'} ) {
        $queue_obj->load( $args{'queue'} );
    } else {
        Jifty->log->debug(
            $args{'queue'} . " not a recognised queue object." );
    }

    #Can't create a ticket without a queue.
    unless ( $queue_obj->id ) {
        Jifty->log->debug("$self No valid queue given for ticket creation.");
        return ( 0, 0, _('Could not create ticket. queue not set') );
    }

    #Now that we have a queue, Check the ACLS
    unless (
        $self->current_user->has_right(
            right  => 'CreateTicket',
            object => $queue_obj
        )
        )
    {
        return (
            0, 0,
            _(  "No permission to create tickets in the queue '%1'",
                $queue_obj->name
            )
        );
    }

    unless ( $queue_obj->is_valid_status( $args{'status'} ) ) {
        return ( 0, 0, _('Invalid value for status') );
    }

    #Since we have a queue, we can set queue defaults

  #Initial priority
  # If there's no queue default initial priority and it's not set, set it to 0
    $args{'initial_priority'} = $queue_obj->initial_priority || 0
        unless defined $args{'initial_priority'};

    #Final priority
    # If there's no queue default final priority and it's not set, set it to 0
    $args{'final_priority'} = $queue_obj->final_priority || 0
        unless defined $args{'final_priority'};

    # priority may have changed from initial_priority, for the case
    # where we're importing tickets (eg, from an older RT version.)
    $args{'priority'} = $args{'initial_priority'}
        unless defined $args{'priority'};

    # {{{ Dates
    #TODO we should see what sort of due date we're getting, rather +
    # than assuming it's in ISO format.

    #Set the due date. if we didn't get fed one, use the queue default due in
    my $due = RT::Date->new();
    if ( defined $args{'due'} ) {
        $due->set( format => 'ISO', value => $args{'due'} );
    } elsif ( my $due_in = $queue_obj->default_due_in ) {
        $due->set_to_now;
        $due->add_days($due_in);
    }

    my $starts = RT::Date->new();
    if ( defined $args{'starts'} ) {
        $starts->set( format => 'ISO', value => $args{'starts'} );
    }

    my $started = RT::Date->new();
    if ( defined $args{'started'} ) {
        $started->set( format => 'ISO', value => $args{'started'} );
    } elsif ( $args{'status'} ne 'new' ) {
        $started->set_to_now;
    }

    my $Resolved = RT::Date->new();
    if ( defined $args{'resolved'} ) {
        $Resolved->set( format => 'ISO', value => $args{'resolved'} );
    }

    #If the status is an inactive status, set the resolved date
    elsif ( $queue_obj->is_inactive_status( $args{'status'} ) ) {
        Jifty->log->debug( "Got a "
                . $args{'status'}
                . "(inactive) ticket with undefined resolved date. Setting to now."
        );
        $Resolved->set_to_now;
    }

    # }}}

    # {{{ Dealing with time fields

    $args{'time_estimated'} = 0 unless defined $args{'time_estimated'};
    $args{'time_worked'}    = 0 unless defined $args{'time_worked'};
    $args{'time_left'}      = 0 unless defined $args{'time_left'};

    # }}}

    # {{{ Deal with setting the owner

    my $owner;
    if ( ref( $args{'owner'} ) && $args{'owner'}->isa('RT::Model::User') ) {
        if ( $args{'owner'}->id ) {
            $owner = $args{'owner'};
        } else {
            Jifty->log->error('passed not loaded owner object');
            push @non_fatal_errors, _("Invalid owner object");
            $owner = undef;
        }
    }

    #If we've been handed something else, try to load the user.
    elsif ( $args{'owner'} ) {
        $owner = RT::Model::User->new;
        $owner->load( $args{'owner'} );
        unless ( $owner->id ) {
            push @non_fatal_errors,
                _("Owner could not be set.") . " "
                . _( "User '%1' could not be found.", $args{'owner'} );
            $owner = undef;
        }
    }

    #If we have a proposed owner and they don't have the right
    #to own a ticket, scream about it and make them not the owner

    my $DeferOwner;
    if (   $owner
        && $owner->id != RT->nobody->id
        && !$owner->has_right( object => $queue_obj, right => 'OwnTicket' ) )
    {
        $DeferOwner = $owner;
        $owner      = undef;
        Jifty->log->debug('going to defer setting owner');

    }

    #If we haven't been handed a valid owner, make it nobody.
    unless ( defined($owner) && $owner->id ) {
        $owner = RT::Model::User->new();
        $owner->load( RT->nobody->id );
    }

    # }}}

# We attempt to load or create each of the people who might have a role for this ticket
# _outside_ the transaction, so we don't get into ticket creation races
    foreach my $type ( "Cc", "AdminCc", "Requestor" ) {
        $args{$type} = [ $args{$type} ] unless ref $args{$type};
        foreach my $watcher ( splice @{ $args{$type} } ) {
            next unless $watcher;
            if ( $watcher =~ /^\d+$/ ) {
                push @{ $args{$type} }, $watcher;
            } else {
                my @addresses = Mail::Address->parse($watcher);
                foreach my $address (@addresses) {
                    my $user = RT::Model::User->new(
                        current_user => RT->system_user );
                    my ( $uid, $msg )
                        = $user->load_or_create_by_email($address);
                    unless ($uid) {
                        push @non_fatal_errors,
                            _( "Couldn't load or create user: %1", $msg );
                    } else {
                        push @{ $args{$type} }, $user->id;
                    }
                }
            }
        }
    }

    Jifty->handle->begin_transaction();

    my %params = (
        queue            => $queue_obj->id,
        owner            => $owner->id,
        subject          => $args{'subject'},
        initial_priority => $args{'initial_priority'},
        final_priority   => $args{'final_priority'},
        priority         => $args{'priority'},
        status           => $args{'status'},
        time_worked      => $args{'time_worked'},
        time_estimated   => $args{'time_estimated'},
        time_left        => $args{'time_left'},
        type             => $args{'type'},
        starts           => $starts->iso,
        started          => $started->iso,
        resolved         => $Resolved->iso,
        due              => $due->iso
    );

# Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id creator created last_updated last_updated_by) {
        $params{$attr} = $args{$attr} if $args{$attr};
    }

    # Delete null integer parameters
    foreach my $attr
        qw(time_worked time_left time_estimated initial_priority final_priority)
    {
        delete $params{$attr}
            unless ( exists $params{$attr} && $params{$attr} );
    }

    # Delete the time worked if we're counting it in the transaction
    delete $params{'time_worked'} if $args{'_record_transaction'};

    my ( $id, $ticket_message ) = $self->SUPER::create(%params);
    unless ($id) {
        Jifty->log->fatal( "Couldn't create a ticket: " . $ticket_message );
        Jifty->handle->rollback();
        return ( 0, 0,
            _("Ticket could not be created due to an internal error") );
    }

    #Set the ticket's effective ID now that we've created it.
    my ( $val, $msg ) = $self->__set(
        column => 'effective_id',
        value  => ( $args{'effective_id'} || $id )
    );
    unless ($val) {
        Jifty->log->fatal("Couldn't set effective_id: $msg\n");
        Jifty->handle->rollback;
        return ( 0, 0,
            _("Ticket could not be created due to an internal error") );
    }

    my $create_groups_ret = $self->_create_ticket_groups();
    unless ($create_groups_ret) {
        Jifty->log->fatal( "Couldn't create ticket groups for ticket "
                . $self->id
                . ". aborting ticket creation." );
        Jifty->handle->rollback();
        return ( 0, 0,
            _("Ticket could not be created due to an internal error") );
    }

# Set the owner in the Groups table
# We denormalize it into the Ticket table too because doing otherwise would
# kill performance, bigtime. It gets kept in lockstep thanks to the magic of transactionalization
    ( $val, $msg ) = $self->owner_group->_add_member(
        principal_id      => $owner->principal_id,
        inside_transaction => 1
    ) unless $DeferOwner;

    # {{{ Deal with setting up watchers

    foreach my $type ( "Cc", "AdminCc", "Requestor" ) {

        # we know it's an array ref
        foreach my $watcher ( @{ $args{$type} } ) {

      # Note that we're using add_watcher, rather than _add_watcher, as we
      # actually _want_ that ACL check. Otherwise, random ticket creators
      # could make themselves adminccs and maybe get ticket rights. that would
      # be poor
            my $method = $type eq 'AdminCc' ? 'add_watcher' : '_add_watcher';

            my ( $val, $msg ) = $self->$method(
                type         => $type,
                principal_id => $watcher,
                silent       => 1,
            );
            push @non_fatal_errors,
                _( "Couldn't set %1 watcher: %2", $type, $msg )
                unless $val;
        }
    }

    # }}}

    # {{{ Add all the custom fields

    foreach my $arg ( keys %args ) {
        next unless $arg =~ /^custom_field-(\d+)$/i;
        my $cfid = $1;

        foreach my $value ( UNIVERSAL::isa( $args{$arg} => 'ARRAY' )
            ? @{ $args{$arg} }
            : ( $args{$arg} ) )
        {
            next unless defined $value && length $value;

            # Allow passing in uploaded LargeContent etc by hash reference
            my ( $status, $msg ) = $self->add_custom_field_value(
                (   UNIVERSAL::isa( $value => 'HASH' )
                    ? %$value
                    : ( Value => $value )
                ),
                Field              => $cfid,
                record_transaction => 0,
            );
            push @non_fatal_errors, $msg unless $status;
        }
    }

    # }}}

    # {{{ Deal with setting up links

    # TODO: Adding link may fire scrips on other end and those scrips
    # could create transactions on this ticket before 'Create' transaction.
    #
    # We should implement different schema: record 'Create' transaction,
    # create links and only then fire create transaction's scrips.
    #
    # Ideal variant: add all links without firing scrips, record create
    # transaction and only then fire scrips on the other ends of links.
    #
    # //RUZ

    foreach my $type ( keys %LINKTYPEMAP ) {
        next unless ( defined $args{$type} );
        foreach my $link (
            ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) )
        {

            # Check rights on the other end of the link if we must
            # then run _add_link that doesn't check for ACLs
            if ( RT->config->get('StrictLinkACL') ) {
                my ( $val, $msg, $obj )
                    = $self->_get_ticket_from_uri( URI => $link );
                unless ($val) {
                    push @non_fatal_errors, $msg;
                    next;
                }

                if ( $obj && !$obj->current_user_has_right('ModifyTicket') ) {
                    push @non_fatal_errors, _('Linking. Permission denied');
                    next;
                }
            }

            my ( $wval, $wmsg ) = $self->_add_link(
                type => $LINKTYPEMAP{$type}->{'type'},
                $LINKTYPEMAP{$type}->{'Mode'} => $link,
                silent => !$args{'_record_transaction'},
                'silent_'
                    . (
                    $LINKTYPEMAP{$type}->{'Mode'} eq 'base'
                    ? 'target'
                    : 'base'
                    ) => 1,
            );

            push @non_fatal_errors, $wmsg unless ($wval);
        }
    }

# }}}
# Now that we've created the ticket and set up its metadata, we can actually go and check OwnTicket on the ticket itself.
# This might be different than before in cases where extensions like RTIR are doing clever things with RT's ACL system
    if ($DeferOwner) {
        if (!$DeferOwner->has_right( object => $self, right => 'OwnTicket' ) )
        {

            Jifty->log->warn( "User "
                    . $owner->name . "("
                    . $owner->id
                    . ") was proposed "
                    . "as a ticket owner but has no rights to own "
                    . "tickets in "
                    . $queue_obj->name );
            push @non_fatal_errors,
                _( "Owner '%1' does not have rights to own this ticket.",
                $owner->name );

        } else {
            $owner = $DeferOwner;
            $self->__set( column => 'owner', value => $owner->id );

        }
        $self->owner_group->_add_member(
            principal_id      => $owner->principal_id,
            inside_transaction => 1
        );
    }

    if ( $args{'_record_transaction'} ) {

        # {{{ Add a transaction for the create
        my ( $Trans, $Msg, $TransObj ) = $self->_new_transaction(
            type          => "Create",
            time_taken     => $args{'time_worked'},
            mime_obj       => $args{'mime_obj'},
            commit_scrips => !$args{'dry_run'},
        );
        if ( $self->id && $Trans ) {

            $TransObj->update_custom_fields( ARGSRef => \%args );

            Jifty->log->info( "Ticket "
                    . $self->id
                    . " created in queue '"
                    . $queue_obj->name . "' by "
                    . $self->current_user->name );
            $ErrStr = _( "Ticket %1 created in queue '%2'",
                $self->id, $queue_obj->name );
            $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
        } else {
            Jifty->handle->rollback();

            $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
            Jifty->log->error("Ticket couldn't be created: $ErrStr");
            return ( 0, 0,
                _("Ticket could not be created due to an internal error") );
        }
        if ( $args{'dry_run'} ) {
            Jifty->handle->rollback();
            return ( $self->id, $TransObj, $ErrStr );
        }

        Jifty->handle->commit();
        return ( $self->id, $TransObj->id, $ErrStr );

        # }}}
    } else {

        # Not going to record a transaction
        Jifty->handle->commit();
        $ErrStr = _( "Ticket %1 created in queue '%2'",
            $self->id, $queue_obj->name );
        $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
        return ( $self->id, 0, $ErrStr );

    }
}

# }}}

# {{{ _Parse822headersForAttributes Content

=head2 _Parse822headersForAttributes Content

Takes an RFC822 style message and parses its attributes into a hash.

=cut

sub _parse822_headers_for_attributes {
    my $self    = shift;
    my $content = shift;
    my %args;

    my @lines = ( split( /\n/, $content ) );
    while ( defined( my $line = shift @lines ) ) {
        if ( $line =~ /^(.*?):(?:\s+(.*))?$/ ) {
            my $value = $2;
            my $tag   = lc($1);

            $tag =~ s/-//g;
            if ( defined( $args{$tag} ) )
            {    #if we're about to get a second value, make it an array
                $args{$tag} = [ $args{$tag} ];
            }
            if ( ref( $args{$tag} ) )
            {    #If it's an array, we want to push the value
                push @{ $args{$tag} }, $value;
            } else {    #if there's nothing there, just set the value
                $args{$tag} = $value;
            }
        } elsif ( $line =~ /^$/ ) {

            #TODO: this won't work, since "" isn't of the form "foo:value"

            while ( defined( my $l = shift @lines ) ) {
                push @{ $args{'content'} }, $l;
            }
        }

    }

    foreach my $date qw(due starts started resolved) {
        my $dateobj = RT::Date->new( current_user => RT->system_user );
        if ( defined( $args{$date} ) and $args{$date} =~ /^\d+$/ ) {
            $dateobj->set( format => 'unix', value => $args{$date} );
        } else {
            $dateobj->set( format => 'unknown', value => $args{$date} );
        }
        $args{$date} = $dateobj->iso;
    }
    $args{'mime_obj'} = MIME::Entity->new();
    $args{'mime_obj'}->build(
        Type => ( $args{'contenttype'} || 'text/plain' ),
        Data => ( $args{'content'}     || '' )
    );

    return (%args);
}

# }}}

# {{{ sub Import

=head2 Import PARAMHASH

Import a ticket. 
Doesn\'t create a transaction. 
Doesn\'t supply queue defaults, etc.

Returns: TICKETID

=cut

sub __import {
    my $self = shift;
    my ( $ErrStr, $queue_obj, $owner );

    my %args = (
        id               => undef,
        effective_id      => undef,
        queue            => undef,
        Requestor        => undef,
        type             => 'ticket',
        owner            => RT->nobody->id,
        subject          => '[no subject]',
        initial_priority => undef,
        final_priority   => undef,
        status           => 'new',
        time_worked      => "0",
        due              => undef,
        created          => undef,
        Updated          => undef,
        resolved         => undef,
        told             => undef,
        @_
    );

    if ( ( defined( $args{'queue'} ) ) && ( !ref( $args{'queue'} ) ) ) {
        $queue_obj = RT::Model::Queue->new( current_user => RT->system_user );
        $queue_obj->load( $args{'queue'} );
    } elsif ( ref( $args{'queue'} ) eq 'RT::Model::Queue' ) {
        $queue_obj = RT::Model::Queue->new( current_user => RT->system_user );
        $queue_obj->load( $args{'queue'}->id );
    } else {
        Jifty->log->debug(
            "$self " . $args{'queue'} . " not a recognised queue object." );
    }

    #Can't create a ticket without a queue.
    unless ( defined($queue_obj) and $queue_obj->id ) {
        Jifty->log->debug("$self No queue given for ticket creation.");
        return ( 0, _('Could not create ticket. queue not set') );
    }

    #Now that we have a queue, Check the ACLS
    unless (
        $self->current_user->has_right(
            right  => 'CreateTicket',
            object => $queue_obj
        )
        )
    {
        return (
            0,
            _(  "No permission to create tickets in the queue '%1'",
                $queue_obj->name
            )
        );
    }

    # {{{ Deal with setting the owner

    # Attempt to take user object, user name or user id.
    # Assign to nobody if lookup fails.
    if ( defined( $args{'owner'} ) ) {
        if ( ref( $args{'owner'} ) ) {
            $owner = $args{'owner'};
        } else {
            $owner = RT::Model::User->new();
            $owner->load( $args{'owner'} );
            if ( !defined( $owner->id ) ) {
                $owner->load( RT->nobody->id );
            }
        }
    }

    #If we have a proposed owner and they don't have the right
    #to own a ticket, scream about it and make them not the owner
    if (    ( defined($owner) )
        and ( $owner->id != RT->nobody->id )
        and (
            !$owner->has_right(
                object => $queue_obj,
                right  => 'OwnTicket'
            )
        )
        )
    {

        Jifty->log->warn( "$self user "
                . $owner->name . "("
                . $owner->id
                . ") was proposed "
                . "as a ticket owner but has no rights to own "
                . "tickets in '"
                . $queue_obj->name
                . "'\n" );

        $owner = undef;
    }

    #If we haven't been handed a valid owner, make it nobody.
    unless ( defined($owner) ) {
        $owner = RT::Model::User->new();
        $owner->load( RT->nobody->user_object->id );
    }

    # }}}

    unless ( $self->validate_status( $args{'status'} ) ) {
        return ( 0,
            _( "'%1' is an invalid value for status", $args{'status'} ) );
    }

    # If we're coming in with an id, set that now.
    my $effective_id = undef;
    if ( $args{'id'} ) {
        $effective_id = $args{'id'};

    }

    my $id = $self->SUPER::create(
        id               => $args{'id'},
        effective_id      => $effective_id,
        queue            => $queue_obj->id,
        owner            => $owner->id,
        subject          => $args{'subject'},             # loc
        initial_priority => $args{'initial_priority'},    # loc
        final_priority   => $args{'final_priority'},      # loc
        priority         => $args{'initial_priority'},    # loc
        status           => $args{'status'},              # loc
        time_worked      => $args{'time_worked'},         # loc
        type             => $args{'type'},                # loc
        created          => $args{'created'},             # loc
        told             => $args{'told'},                # loc
        last_updated      => $args{'Updated'},             # loc
        resolved         => $args{'resolved'},            # loc
        due              => $args{'due'},                 # loc
    );

    # If the ticket didn't have an id
    # Set the ticket's effective ID now that we've created it.
    if ( $args{'id'} ) {
        $self->load( $args{'id'} );
    } else {
        my ( $val, $msg )
            = $self->__set( column => 'effective_id', value => $id );

        unless ($val) {
            Jifty->log->err(
                $self . "->import couldn't set effective_id: $msg\n" );
        }
    }

    my $create_groups_ret = $self->_create_ticket_groups();
    unless ($create_groups_ret) {
        Jifty->log->fatal(
            "Couldn't create ticket groups for ticket " . $self->id );
    }

    $self->owner_group->_add_member( principal_id => $owner->principal_id );

    my $watcher;
    foreach $watcher ( @{ $args{'Cc'} } ) {
        $self->_add_watcher( type => 'Cc', email => $watcher, silent => 1 );
    }
    foreach $watcher ( @{ $args{'AdminCc'} } ) {
        $self->_add_watcher(
            type   => 'AdminCc',
            email  => $watcher,
            silent => 1
        );
    }
    foreach $watcher ( @{ $args{'Requestor'} } ) {
        $self->_add_watcher(
            type   => 'Requestor',
            email  => $watcher,
            silent => 1
        );
    }

    return ( $self->id, $ErrStr );
}

# }}}

# {{{ Routines dealing with watchers.

# {{{ _create_ticket_groups

=head2 _create_ticket_groups

Create the ticket groups and links for this ticket. 
This routine expects to be called from Ticket->create _inside of a transaction_

It will create four groups for this ticket: Requestor, Cc, AdminCc and Owner.

It will return true on success and undef on failure.


=cut

sub _create_ticket_groups {
    my $self = shift;

    my @types = qw(Requestor Owner Cc AdminCc);

    foreach my $type (@types) {
        my $type_obj = RT::Model::Group->new;
        my ( $id, $msg ) = $type_obj->create_role_group(
            domain   => 'RT::Model::Ticket-Role',
            instance => $self->id,
            type     => $type
        );
        unless ($id) {
            Jifty->log->error(
                "Couldn't create a ticket group of type '$type' for ticket "
                    . $self->id . ": "
                    . $msg );
            return (undef);
        }
    }
    return (1);

}

# }}}

# {{{ sub owner_group

=head2 owner_group

A constructor which returns an RT::Model::Group object containing the owner of this ticket.

=cut

sub owner_group {
    my $self      = shift;
    my $owner_obj = RT::Model::Group->new;
    $owner_obj->load_ticket_role_group(
        ticket => $self->id,
        type   => 'Owner'
    );
    return ($owner_obj);
}

# }}}

# {{{ sub add_watcher

=head2 add_watcher

add_watcher takes a parameter hash. The keys are as follows:

Type        One of Requestor, Cc, AdminCc

prinicpal_id The RT::Model::Principal id of the user or group that's being added as a watcher

email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the email parameter to their email address.

=cut

sub add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    # ModifyTicket works in any case
    return $self->_add_watcher(%args)
        if $self->current_user_has_right('ModifyTicket');

    if ( $args{'email'} ) {
        my ($addr) = Mail::Address->parse( $args{'email'} );
        return ( 0,
            _( "Couldn't parse address from '%1 string", $args{'email'} ) )
            unless $addr;

        if (lc $self->current_user->user_object->email eq
            lc RT::Model::User->canonicalize_email( $addr->address ) )
        {
            $args{'principal_id'} = $self->current_user->id;
            delete $args{'email'};
        }
    }

    # If the watcher isn't the current user then the current user has no right
    # bail
    unless ( $args{'principal_id'}
        && $self->current_user->id == $args{'principal_id'} )
    {
        return ( 0, _("Permission Denied") );
    }

    #  If it's an AdminCc and they don't have 'WatchAsAdminCc', bail
    if ( $args{'type'} eq 'AdminCc' ) {
        unless ( $self->current_user_has_right('WatchAsAdminCc') ) {
            return ( 0, _('Permission Denied') );
        }
    }

    #  If it's a Requestor or Cc and they don't have 'Watch', bail
    elsif ( $args{'type'} eq 'Cc' || $args{'type'} eq 'Requestor' ) {
        unless ( $self->current_user_has_right('Watch') ) {
            return ( 0, _('Permission Denied') );
        }
    } else {
        Jifty->log->warn("add_watcher got passed a bogus type");
        return ( 0, _('Error in parameters to Ticket->add_watcher') );
    }

    return $self->_add_watcher(%args);
}

#This contains the meat of add_watcher. but can be called from a routine like
# Create, which doesn't need the additional acl check
sub _add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        silent       => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    my $principal = RT::Model::Principal->new;
    if ( $args{'email'} ) {
        my $user = RT::Model::User->new( current_user => RT->system_user );
        my ( $pid, $msg ) = $user->load_or_create_by_email( $args{'email'} );
        $args{'principal_id'} = $pid if $pid;
    }
    if ( $args{'principal_id'} ) {
        $principal->load( $args{'principal_id'} );
    }

    # If we can't find this watcher, we need to bail.
    unless ( $principal->id ) {
        Jifty->log->error(
                  "Could not load create a user with the email address '"
                . $args{'email'}
                . "' to add as a watcher for ticket "
                . $self->id );
        return ( 0, _("Could not find or create that user") );
    }

    my $group = RT::Model::Group->new;
    $group->load_ticket_role_group(
        type   => $args{'type'},
        ticket => $self->id
    );
    unless ( $group->id ) {
        return ( 0, _("Group not found") );
    }

    if ( $group->has_member($principal) ) {

        return (
            0,
            _(  'That principal is already a %1 for this ticket',
                _( $args{'type'} )
            )
        );
    }

    my ( $m_id, $m_msg ) = $group->_add_member(
        principal_id      => $principal->id,
        inside_transaction => 1
    );
    unless ($m_id) {
        Jifty->log->error( "Failed to add "
                . $principal->id
                . " as a member of group "
                . $group->id . "\n"
                . $m_msg );

        return (
            0,
            _(  'Could not make that principal a %1 for this ticket',
                _( $args{'type'} )
            )
        );
    }

    unless ( $args{'silent'} ) {
        $self->_new_transaction(
            type      => 'AddWatcher',
            new_value => $principal->id,
            field     => $args{'type'}
        );
    }

    return ( 1,
        _( 'Added principal as a %1 for this ticket', _( $args{'type'} ) ) );
}

# }}}

# {{{ sub delete_watcher

=head2 delete_watcher { type => TYPE, principal_id => PRINCIPAL_ID, email => EMAIL_ADDRESS }


Deletes a ticket watcher.  Takes two arguments:

Type  (one of Requestor,Cc,AdminCc)

and one of

principal_id (an RT::Model::Principal id of the watcher you want to remove)
    OR
email (the email address of an existing wathcer)


=cut

sub delete_watcher {
    my $self = shift;

    my %args = (
        type         => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    unless ( $args{'principal_id'} || $args{'email'} ) {
        return ( 0, _("No principal specified") );
    }
    my $principal = RT::Model::Principal->new;
    if ( $args{'principal_id'} ) {

        $principal->load( $args{'principal_id'} );
    } else {
        my $user = RT::Model::User->new;
        $user->load_by_email( $args{'email'} );
        $principal->load( $user->id );
    }

    # If we can't find this watcher, we need to bail.
    unless ( $principal->id ) {
        return ( 0, _("Could not find that principal") );
    }

    my $group = RT::Model::Group->new;
    $group->load_ticket_role_group(
        type   => $args{'type'},
        ticket => $self->id
    );
    unless ( $group->id ) {
        return ( 0, _("Group not found") );
    }

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->current_user->id == $principal->id ) {

        #  If it's an AdminCc and they don't have
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( $args{'type'} eq 'AdminCc' ) {
            unless ( $self->current_user_has_right('ModifyTicket')
                or $self->current_user_has_right('WatchAsAdminCc') )
            {
                return ( 0, _('Permission Denied') );
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif (( $args{'type'} eq 'Cc' )
            or ( $args{'type'} eq 'Requestor' ) )
        {
            unless ( $self->current_user_has_right('ModifyTicket')
                or $self->current_user_has_right('Watch') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            Jifty->log->warn(
                "$self -> delete_watcher got passed a bogus type");
            return ( 0, _('Error in parameters to Ticket->delete_watcher') );
        }
    }

    # If the watcher isn't the current user
    # and the current user  doesn't have 'ModifyTicket' bail
    else {
        unless ( $self->current_user_has_right('ModifyTicket') ) {
            return ( 0, _("Permission Denied") );
        }
    }

    # }}}

    # see if this user is already a watcher.

    unless ( $group->has_member($principal) ) {
        return ( 0,
            _( 'That principal is not a %1 for this ticket', $args{'type'} )
        );
    }

    my ( $m_id, $m_msg ) = $group->_delete_member( $principal->id );
    unless ($m_id) {
        Jifty->log->error( "Failed to delete "
                . $principal->id
                . " as a member of group "
                . $group->id . "\n"
                . $m_msg );

        return (
            0,
            _(  'Could not remove that principal as a %1 for this ticket',
                $args{'type'}
            )
        );
    }

    unless ( $args{'silent'} ) {
        $self->_new_transaction(
            type      => 'del_watcher',
            old_value => $principal->id,
            field     => $args{'type'}
        );
    }

    return (
        1,
        _(  "%1 is no longer a %2 for this ticket.",
            $principal->object->name,
            $args{'type'}
        )
    );
}

# }}}

=head2 squelch_mail_to [EMAIL]

Takes an optional email address to never email about updates to this ticket.


Returns an array of the RT::Model::Attribute objects for this ticket's 'SquelchMailTo' attributes.


=cut

sub squelch_mail_to {
    my $self = shift;
    if (@_) {
        unless ( $self->current_user_has_right('ModifyTicket') ) {
            return undef;
        }
        my $attr = shift;
        $self->add_attribute( name => 'SquelchMailTo', content => $attr )
            unless grep { $_->content eq $attr }
                $self->attributes->named('SquelchMailTo');

    }
    unless ( $self->current_user_has_right('ShowTicket') ) {
        return undef;
    }
    my @attributes = $self->attributes->named('SquelchMailTo');
    return (@attributes);
}

=head2 unsquelch_mail_to ADDRESS

Takes an address and removes it from this ticket's "SquelchMailTo" list. If an address appears multiple times, each instance is removed.

Returns a tuple of (status, message)

=cut

sub unsquelch_mail_to {
    my $self = shift;

    my $address = shift;
    unless ( $self->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    my ( $val, $msg ) = $self->attributes->delete_entry(
        name    => 'SquelchMailTo',
        Content => $address
    );
    return ( $val, $msg );
}

# {{{ a set of  [foo]AsString subs that will return the various sorts of watchers for a ticket/queue as a comma delineated string

=head2 requestor_addresses

 B<Returns> String: All Ticket Requestor email addresses as a string.

=cut

sub requestor_addresses {
    my $self = shift;

    unless ( $self->current_user_has_right('ShowTicket') ) {
        return undef;
    }

    return ( $self->requestors->member_emails_as_string );
}

=head2 admin_cc_addresses

returns String: All Ticket AdminCc email addresses as a string

=cut

sub admin_cc_addresses {
    my $self = shift;

    unless ( $self->current_user_has_right('ShowTicket') ) {
        return undef;
    }

    return ( $self->admin_cc->member_emails_as_string )

}

=head2 cc_addresses

returns String: All Ticket Ccs as a string of email addresses

=cut

sub cc_addresses {
    my $self = shift;

    unless ( $self->current_user_has_right('ShowTicket') ) {
        return undef;
    }
    return ( $self->cc->member_emails_as_string );

}

# }}}

# {{{ Routines that return RT::Watchers objects of Requestors, Ccs and AdminCcs

# {{{ sub Requestors

=head2 Requestors

Takes nothing.
Returns this ticket's Requestors as an RT::Model::Group object

=cut

sub requestors {
    my $self = shift;

    my $group = RT::Model::Group->new;
    if ( $self->current_user_has_right('ShowTicket') ) {
        $group->load_ticket_role_group(
            type   => 'Requestor',
            ticket => $self->id
        );
    }
    return ($group);

}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns an RT::Model::Group object which contains this ticket's Ccs.
If the user doesn't have "ShowTicket" permission, returns an empty group

=cut

sub cc {
    my $self = shift;

    my $group = RT::Model::Group->new;
    if ( $self->current_user_has_right('ShowTicket') ) {
        $group->load_ticket_role_group( type => 'Cc', ticket => $self->id );
    }
    return ($group);

}

# }}}

# {{{ sub admin_cc

=head2 admin_cc

Takes nothing.
Returns an RT::Model::Group object which contains this ticket's AdminCcs.
If the user doesn't have "ShowTicket" permission, returns an empty group

=cut

sub admin_cc {
    my $self  = shift;
    my $group = RT::Model::Group->new;
    if ( $self->current_user_has_right('ShowTicket') ) {
        $group->load_ticket_role_group(
            type   => 'AdminCc',
            ticket => $self->id
        );
    }
    return ($group);

}

# }}}

# }}}

# {{{ is_watcher,is_requestor,is_cc, is_admin_cc

# {{{ sub is_watcher
# a generic routine to be called by is_requestor, is_cc and is_admin_cc

=head2 is_watcher { type => TYPE, principal_id => PRINCIPAL_ID, email => EMAIL }

Takes a param hash with the attributes type and either principal_id or email

Type is one of Requestor, Cc, AdminCc and Owner

principal_id is an RT::Model::Principal id, and email is an email address.

Returns true if the specified principal (or the one corresponding to the
specified address) is a member of the group type for this ticket.

XX TODO: This should be Memoized. 

=cut

sub is_watcher {
    my $self = shift;

    my %args = (
        type         => 'Requestor',
        principal_id => undef,
        email        => undef,
        @_
    );

    # Load the relevant group.
    my $group = RT::Model::Group->new;
    $group->load_ticket_role_group(
        type   => $args{'type'},
        ticket => $self->id
    );

    # Find the relevant principal.
    if ( !$args{principal_id} && $args{email} ) {

        # Look up the specified user.
        my $user = RT::Model::User->new;
        $user->load_by_email( $args{email} );
        if ( $user->id ) {
            $args{principal_id} = $user->principal_id;
        } else {

            # A non-existent user can't be a group member.
            return 0;
        }
    }

    # Ask if it has the member in question
    return $group->has_member( $args{'principal_id'} );
}

# }}}

# {{{ sub is_requestor

=head2 is_requestor PRINCIPAL_ID
  
Takes an L<RT::Model::Principal> id.

Returns true if the principal is a requestor of the current ticket.

=cut

sub is_requestor {
    my $self   = shift;
    my $person = shift;

    return (
        $self->is_watcher( type => 'Requestor', principal_id => $person ) );

}

# }}}

# {{{ sub is_cc

=head2 is_cc PRINCIPAL_ID

  Takes an RT::Model::Principal id.
  Returns true if the principal is a requestor of the current ticket.


=cut

sub is_cc {
    my $self = shift;
    my $cc   = shift;

    return ( $self->is_watcher( type => 'Cc', principal_id => $cc ) );

}

# }}}

# {{{ sub is_admin_cc

=head2 is_admin_cc PRINCIPAL_ID

  Takes an RT::Model::Principal id.
  Returns true if the principal is a requestor of the current ticket.

=cut

sub is_admin_cc {
    my $self   = shift;
    my $person = shift;

    return (
        $self->is_watcher( type => 'AdminCc', principal_id => $person ) );

}

# }}}

# {{{ sub is_owner

=head2 is_owner

  Takes an RT::Model::User object. Returns true if that user is this ticket's owner.
returns undef otherwise

=cut

sub is_owner {
    my $self   = shift;
    my $person = shift;

    # no ACL check since this is used in acl decisions
    # unless ($self->current_user_has_right('ShowTicket')) {
    #    return(undef);
    #   }

    #Tickets won't yet have owners when they're being created.
    unless ( $self->owner_obj->id ) {
        return (undef);
    }

    if ( $person->id == $self->owner_obj->id ) {
        return (1);
    } else {
        return (undef);
    }
}

# }}}

# }}}

# }}}

=head2 transaction_addresses

Returns a composite hashref of the results of L<RT::Model::Transaction/Addresses> for all this ticket's Create, comment or Correspond transactions.
The keys are C<To>, C<Cc> and C<Bcc>. The values are lists of C<Mail::Address> objects.

NOTE: For performance reasons, this method might want to skip transactions and go straight for attachments. But to make that work right, we're going to need to go and walk around the access control in Attachment.pm's sub _value.

=cut

sub transaction_addresses {
    my $self = shift;
    my $txns = $self->transactions;

    my %addresses = ();
    foreach my $type (qw(Create comment Correspond)) {
        $txns->limit(
            column           => 'type',
            operator         => '=',
            value            => $type,
            entry_aggregator => 'OR',
            case_sensitive   => 1
        );
    }

    while ( my $txn = $txns->next ) {
        my $txnaddrs = $txn->addresses;
        foreach my $addrlist ( values %$txnaddrs ) {
            foreach my $addr (@$addrlist) {

# Skip addresses without a phrase (things that are just raw addresses) if we have a phrase
                next
                    if ( $addresses{ $addr->address }
                    && $addresses{ $addr->address }->phrase
                    && not $addr->phrase );
                $addresses{ $addr->address } = $addr;
            }
        }
    }

    return \%addresses;

}

# {{{ Routines dealing with queues

# {{{ sub validate_Queue

sub validate_queue {
    my $self  = shift;
    my $value = shift;

    if ( !$value ) {
        Jifty->log->warn(
            " RT:::Queue::validate_Queue called with a null value. this isn't ok."
        );
        return (1);
    }

    my $queue_obj = RT::Model::Queue->new;
    my $id        = $queue_obj->load($value);

    if ($id) {
        return (1);
    } else {
        return (undef);
    }
}

# }}}

# {{{ sub set_Queue

sub set_queue {
    my $self     = shift;
    my $NewQueue = shift;

    #Redundant. ACL gets checked in _set;
    unless ( $self->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    my $Newqueue_obj = RT::Model::Queue->new;
    $Newqueue_obj->load($NewQueue);

    unless ( $Newqueue_obj->id() ) {
        return ( 0, _("That queue does not exist") );
    }

    if ( $Newqueue_obj->id == $self->queue_obj->id ) {
        return ( 0, _('That is the same value') );
    }
    unless (
        $self->current_user->has_right(
            right  => 'CreateTicket',
            object => $Newqueue_obj
        )
        )
    {
        return ( 0, _("You may not create requests in that queue.") );
    }

    unless (
        $self->owner_obj->has_right(
            right  => 'OwnTicket',
            object => $Newqueue_obj
        )
        )
    {
        my $clone = RT::Model::Ticket->new( current_user => RT->system_user );
        $clone->load( $self->id );
        unless ( $clone->id ) {
            return ( 0, _( "Couldn't load copy of ticket #%1.", $self->id ) );
        }
        my ( $status, $msg ) = $clone->set_owner( RT->nobody->id, 'Force' );
        Jifty->log->error("Couldn't set owner on queue change: $msg")
            unless $status;
    }

    return ( $self->_set( column => 'queue', value => $Newqueue_obj->id() ) );
}

# }}}

# {{{ sub queue_obj

=head2 queue_obj

Takes nothing. returns this ticket's queue object

=cut

sub queue_obj {
    my $self = shift;

    my $queue_obj = RT::Model::Queue->new;

#We call __value so that we can avoid the ACL decision and some deep recursion
    my ($result) = $queue_obj->load( $self->__value('queue') );
    return ($queue_obj);
}

# }}}

# }}}

# {{{ date printing routines

# {{{ sub due_obj

=head2 due_obj

  Returns an RT::Date object containing this ticket's due date

=cut

sub due_obj {
    my $self = shift;

    my $time = RT::Date->new();

    # -1 is RT::Date slang for never
    if ( my $due = $self->due ) {
        $time->set( format => 'sql', value => $due );
    } else {
        $time->set( format => 'unix', value => -1 );
    }

    return $time;
}

# }}}

# {{{ sub due_as_string

=head2 due_as_string

Returns this ticket's due date as a human readable string

=cut

sub due_as_string {
    my $self = shift;
    return $self->due_obj->as_string();
}

# }}}

# {{{ sub resolved_obj

=head2 resolved_obj

  Returns an RT::Date object of this ticket's 'resolved' time.

=cut

sub resolved_obj {
    my $self = shift;

    my $time = RT::Date->new();
    $time->set( format => 'sql', value => $self->resolved );
    return $time;
}

# }}}

# {{{ sub set_Started

=head2 set_started

Takes a date in ISO format or undef
Returns a transaction id and a message
The client calls "Start" to note that the project was started on the date in $date.
A null date means "now"

=cut

sub set_started {
    my $self = shift;
    my $time = shift || 0;

    unless ( $self->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    #We create a date object to catch date weirdness
    my $time_obj = RT::Date->new( $self->current_user() );
    if ($time) {
        $time_obj->set( format => 'ISO', value => $time );
    } else {
        $time_obj->set_to_now();
    }

    #Now that we're starting, open this ticket
    #TODO do we really want to force this as policy? it should be a scrip

    #We need $TicketAsSystem, in case the current user doesn't have
    #ShowTicket
    #
    my $TicketAsSystem = RT::Model::Ticket->new( RT->system_user );
    $TicketAsSystem->load( $self->id );
    if ( $TicketAsSystem->status eq 'new' ) {
        $TicketAsSystem->open();
    }

    return ( $self->_set( column => 'started', value => $time_obj->iso ) );

}

# }}}

# {{{ sub started_obj

=head2 started_obj

  Returns an RT::Date object which contains this ticket's 
'started' time.

=cut

sub started_obj {
    my $self = shift;

    my $time = RT::Date->new();
    $time->set( format => 'sql', value => $self->started );
    return $time;
}

# }}}

# {{{ sub startsObj

=head2 startsObj

  Returns an RT::Date object which contains this ticket's 
'starts' time.

=cut

sub starts_obj {
    my $self = shift;

    my $time = RT::Date->new();
    $time->set( format => 'sql', value => $self->starts );
    return $time;
}

# }}}

# {{{ sub told_obj

=head2 told_obj

  Returns an RT::Date object which contains this ticket's 
'told' time.

=cut

sub told_obj {
    my $self = shift;

    my $time = RT::Date->new();
    $time->set( format => 'sql', value => $self->told );
    return $time;
}

# }}}

# {{{ sub told_as_string

=head2 told_as_string

A convenience method that returns told_obj->as_string

TODO: This should be deprecated

=cut

sub told_as_string {
    my $self = shift;
    if ( $self->told ) {
        return $self->told_obj->as_string();
    } else {
        return ("Never");
    }
}

# }}}

# {{{ sub time_workedAsString

=head2 time_workedAsString

Returns the amount of time worked on this ticket as a Text String

=cut

sub time_worked_as_string {
    my $self = shift;
    return "0" unless $self->time_worked;

    #This is not really a date object, but if we diff a number of seconds
    #vs the epoch, we'll get a nice description of time worked.

    my $worked = RT::Date->new();

    #return the  #of minutes worked turned into seconds and written as
    # a simple text string

    return ( $worked->duration_as_string( $self->time_worked * 60 ) );
}

# }}}

# }}}

# {{{ Routines dealing with correspondence/comments

# {{{ sub comment

=head2 comment

comment on this ticket.
Takes a hashref with the following attributes:
If mime_obj is undefined, Content will be used to build a MIME::Entity for this
commentl

mime_obj, time_taken, CcMessageTo, BccMessageTo, Content, dry_run

If dry_run is defined, this update WILL NOT BE RECORDED. Scrips will not be committed.
They will, however, be prepared and you'll be able to access them through the transaction_obj

Returns: Transaction id, Error Message, Transaction object
(note the different order from Create()!)

=cut

sub comment {
    my $self = shift;

    my %args = (
        CcMessageTo  => undef,
        BccMessageTo => undef,
        mime_obj      => undef,
        Content      => undef,
        time_taken    => 0,
        dry_run       => 0,
        @_
    );

    unless ( ( $self->current_user_has_right('CommentOnTicket') )
        or ( $self->current_user_has_right('ModifyTicket') ) )
    {
        return ( 0, _("Permission Denied"), undef );
    }
    $args{'NoteType'} = 'comment';

    if ( $args{'dry_run'} ) {
        Jifty->handle->begin_transaction();
        $args{'commit_scrips'} = 0;
    }

    my @results = $self->_record_note(%args);
    if ( $args{'dry_run'} ) {
        Jifty->handle->rollback();
    }

    return (@results);
}

# }}}

=head2 correspond

Correspond on this ticket.
Takes a hashref with the following attributes:


mime_obj, time_taken, CcMessageTo, BccMessageTo, Content, dry_run

if there's no mime_obj, Content is used to build a MIME::Entity object

If dry_run is defined, this update WILL NOT BE RECORDED. Scrips will not be committed.
They will, however, be prepared and you'll be able to access them through the transaction_obj

Returns: Transaction id, Error Message, Transaction object
(note the different order from Create()!)


=cut

sub correspond {
    my $self = shift;
    my %args = (
        CcMessageTo  => undef,
        BccMessageTo => undef,
        mime_obj      => undef,
        Content      => undef,
        time_taken    => 0,
        @_
    );

    unless ( ( $self->current_user_has_right('ReplyToTicket') )
        or ( $self->current_user_has_right('ModifyTicket') ) )
    {
        return ( 0, _("Permission Denied"), undef );
    }

    $args{'NoteType'} = 'Correspond';
    if ( $args{'dry_run'} ) {
        Jifty->handle->begin_transaction();
        $args{'commit_scrips'} = 0;
    }

    my @results = $self->_record_note(%args);

#Set the last told date to now if this isn't mail from the requestor.
#TODO: Note that this will wrongly ack mail from any non-requestor as a "told"
    $self->set_told unless ( $self->is_requestor( $self->current_user->id ) );

    if ( $args{'dry_run'} ) {
        Jifty->handle->rollback();
    }

    return (@results);

}

# }}}

# {{{ sub _RecordNote

=head2 _RecordNote

the meat of both comment and correspond. 

Performs no access control checks. hence, dangerous.

=cut

sub _record_note {
    my $self = shift;
    my %args = (
        CcMessageTo   => undef,
        BccMessageTo  => undef,
        encrypt       => undef,
        sign          => undef,
        mime_obj       => undef,
        Content       => undef,
        NoteType      => 'Correspond',
        time_taken     => 0,
        commit_scrips => 1,
        @_
    );

    unless ( $args{'mime_obj'} || $args{'Content'} ) {
        return ( 0, _("No message attached"), undef );
    }

    unless ( $args{'mime_obj'} ) {
        $args{'mime_obj'} = MIME::Entity->build(
            Data => (
                ref $args{'Content'} ? $args{'Content'} : [ $args{'Content'} ]
            )
        );
    }

    # convert text parts into utf-8
    RT::I18N::set_mime_entity_to_utf8( $args{'mime_obj'} );

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT-Send-Cc: and
    # RT-Send-Bcc: headers

    foreach my $type (qw/Cc Bcc/) {
        if ( defined $args{ $type . 'MessageTo' } ) {

            my $addresses = join ', ',
                ( map { RT::Model::User->canonicalize_email( $_->address ) }
                    Mail::Address->parse( $args{ $type . 'MessageTo' } ) );
            $args{'mime_obj'}->head->add( 'RT-Send-' . $type, $addresses );
        }
    }

    foreach my $argument (qw(encrypt sign)) {
        $args{'mime_obj'}->head->add( "X-RT-$argument" => $args{$argument} )
            if defined $args{$argument};
    }

    # XXX: This code is duplicated several times
    # If this is from an external source, we need to come up with its
    # internal Message-ID now, so all emails sent because of this
    # message have a common Message-ID
    my $org   = RT->config->get('organization');
    my $msgid = $args{'mime_obj'}->head->get('Message-ID');
    unless ( defined $msgid
        && $msgid =~ /<(rt-.*?-\d+-\d+)\.(\d+-0-0)\@\Q$org\E>/ )
    {
        $args{'mime_obj'}->head->set( 'RT-Message-ID' =>
                RT::Interface::Email::gen_message_id( Ticket => $self ) );
    }

    #Record the correspondence (write the transaction)
    my ( $Trans, $msg, $TransObj ) = $self->_new_transaction(
        type => $args{'NoteType'},
        Data => ( $args{'mime_obj'}->head->get('subject') || 'No subject' ),
        time_taken     => $args{'time_taken'},
        mime_obj       => $args{'mime_obj'},
        commit_scrips => $args{'commit_scrips'},
    );

    unless ($Trans) {
        Jifty->log->err("$self couldn't init a transaction $msg");
        return ( $Trans, _("Message could not be recorded"), undef );
    }

    return ( $Trans, _("Message recorded"), $TransObj );
}

# }}}

# }}}

# {{{ sub _links

sub _links {
    my $self = shift;

#TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
#tobias meant by $f
    my $field = shift;
    my $type = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = RT::Model::LinkCollection->new(
            current_user => $self->current_user );
        if ( $self->current_user_has_right('ShowTicket') ) {

            # Maybe this ticket is a merged ticket
            my $Tickets = RT::Model::TicketCollection->new();

            # at least to myself
            $self->{"$field$type"}->limit(
                column           => $field,
                value            => $self->uri,
                entry_aggregator => 'OR'
            );
            $Tickets->limit(
                column => 'effective_id',
                value  => $self->effective_id
            );
            while ( my $Ticket = $Tickets->next ) {
                $self->{"$field$type"}->limit(
                    column           => $field,
                    value            => $Ticket->uri,
                    entry_aggregator => 'OR'
                );
            }
            $self->{"$field$type"}->limit(
                column => 'type',
                value  => $type
            ) if ($type);
        }
    }
    return ( $self->{"$field$type"} );
}

# }}}

# {{{ sub delete_link

=head2 delete_link

Delete a link. takes a paramhash of base, target, Type, silent,
silent_base and silent_target. Either base or target must be null.
The null value will be replaced with this ticket\'s id.

If silent is true then no transaction would be recorded, in other
case you can control creation of transactions on both base and
target with silent_base and silent_target respectively. By default
both transactions are created.

=cut 

sub delete_link {
    my $self = shift;
    my %args = (
        base         => undef,
        target       => undef,
        type         => undef,
        silent       => undef,
        silent_base   => undef,
        silent_target => undef,
        @_
    );

    unless ( $args{'target'} || $args{'base'} ) {
        Jifty->log->error("base or target must be specified\n");
        return ( 0, _('Either base or target must be specified') );
    }

    #check acls
    my $right = 0;
    $right++ if $self->current_user_has_right('ModifyTicket');
    if ( !$right && RT->config->get('StrictLinkACL') ) {
        return ( 0, _("Permission Denied") );
    }

    # If the other URI is an RT::Model::Ticket, we want to make sure the user
    # can modify it too...
    my ( $status, $msg, $other_ticket )
        = $self->_get_ticket_from_uri( URI => $args{'target'}
            || $args{'base'} );
    return ( 0, $msg ) unless $status;
    if ( !$other_ticket
        || $other_ticket->current_user_has_right('ModifyTicket') )
    {
        $right++;
    }
    if (   ( !RT->config->get('StrictLinkACL') && $right == 0 )
        || ( RT->config->get('StrictLinkACL') && $right < 2 ) )
    {
        return ( 0, _("Permission Denied") );
    }

    my ( $val, $Msg ) = $self->SUPER::_delete_link(%args);
    return ( 0, $Msg ) unless $val;

    return ( $val, $Msg ) if $args{'silent'};

    my ( $direction, $remote_link );

    if ( $args{'base'} ) {
        $remote_link = $args{'base'};
        $direction   = 'target';
    } elsif ( $args{'target'} ) {
        $remote_link = $args{'target'};
        $direction   = 'base';
    }

    my $remote_uri = RT::URI->new;
    $remote_uri->from_uri($remote_link);

    unless ( $args{ 'silent_' . $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_new_transaction(
            type      => 'DeleteLink',
            field     => $LINKDIRMAP{ $args{'type'} }->{$direction},
            old_value => $remote_uri->uri || $remote_link,
            time_taken => 0
        );
        Jifty->log->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{ 'silent_' . ( $direction eq 'target' ? 'base' : 'target' ) }
        && $remote_uri->is_local )
    {
        my $OtherObj = $remote_uri->object;
        my ( $val, $Msg ) = $OtherObj->_new_transaction(
            type  => 'DeleteLink',
            field => $direction eq 'target'
            ? $LINKDIRMAP{ $args{'type'} }->{base}
            : $LINKDIRMAP{ $args{'type'} }->{target},
            old_value      => $self->uri,
            activate_scrips => !RT->config->get('LinkTransactionsRun1Scrip'),
            time_taken      => 0,
        );
        Jifty->log->error("Couldn't create transaction: $Msg") unless $val;
    }

    return ( $val, $Msg );
}

# }}}

# {{{ sub add_link

=head2 add_link

Takes a paramhash of type and one of base or target. Adds that link to this ticket.

If silent is true then no transaction would be recorded, in other
case you can control creation of transactions on both base and
target with silent_base and silent_target respectively. By default
both transactions are created.

=cut

sub add_link {
    my $self = shift;
    my %args = (
        target       => '',
        base         => '',
        type         => '',
        silent       => undef,
        silent_base   => undef,
        silent_target => undef,
        @_
    );

    unless ( $args{'target'} || $args{'base'} ) {
        Jifty->log->error("base or target must be specified\n");
        return ( 0, _('Either base or target must be specified') );
    }

    my $right = 0;
    $right++ if $self->current_user_has_right('ModifyTicket');
    if ( !$right && RT->config->get('StrictLinkACL') ) {
        return ( 0, _("Permission Denied") );
    }

    # If the other URI is an RT::Model::Ticket, we want to make sure the user
    # can modify it too...
    my ( $status, $msg, $other_ticket )
        = $self->_get_ticket_from_uri( URI => $args{'target'}
            || $args{'base'} );
    return ( 0, $msg ) unless $status;
    if ( !$other_ticket
        || $other_ticket->current_user_has_right('ModifyTicket') )
    {
        $right++;
    }
    if (   ( !RT->config->get('StrictLinkACL') && $right == 0 )
        || ( RT->config->get('StrictLinkACL') && $right < 2 ) )
    {
        return ( 0, _("Permission Denied") );
    }

    return $self->_add_link(%args);
}

sub _get_ticket_from_uri {
    my $self = shift;
    my %args = ( URI => '', @_ );

    # If the other URI is an RT::Model::Ticket, we want to make sure the user
    # can modify it too...
    my $uri_obj = RT::URI->new;
    $uri_obj->from_uri( $args{'URI'} );

    unless ( $uri_obj->resolver && $uri_obj->scheme ) {
        my $msg = _( "Couldn't resolve '%1' into a URI.", $args{'URI'} );
        Jifty->log->warn("$msg\n");
        return ( 0, $msg );
    }
    my $obj = $uri_obj->resolver->object;
    unless ( UNIVERSAL::isa( $obj, 'RT::Model::Ticket' ) && $obj->id ) {
        return ( 1, 'Found not a ticket', undef );
    }
    return ( 1, 'Found ticket', $obj );
}

=head2 _add_link  

Private non-acled variant of add_link so that links can be added during create.

=cut

sub _add_link {
    my $self = shift;
    my %args = (
        target       => '',
        base         => '',
        type         => '',
        silent       => undef,
        silent_base   => undef,
        silent_target => undef,
        @_
    );

    my ( $val, $msg, $exist ) = $self->SUPER::_add_link(%args);
    return ( $val, $msg ) if !$val || $exist;
    return ( $val, $msg ) if $args{'silent'};

    my ( $direction, $remote_link );
    if ( $args{'target'} ) {
        $remote_link = $args{'target'};
        $direction   = 'base';
    } elsif ( $args{'base'} ) {
        $remote_link = $args{'base'};
        $direction   = 'target';
    }

    my $remote_uri = RT::URI->new;
    $remote_uri->from_uri($remote_link);

    unless ( $args{ 'silent_' . $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_new_transaction(
            type      => 'AddLink',
            field     => $LINKDIRMAP{ $args{'type'} }->{$direction},
            new_value => $remote_uri->uri || $remote_link,
            time_taken => 0
        );
        Jifty->log->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{ 'silent_' . ( $direction eq 'target' ? 'base' : 'target' ) }
        && $remote_uri->is_local )
    {
        my $OtherObj = $remote_uri->object;
        my ( $val, $msg ) = $OtherObj->_new_transaction(
            type  => 'AddLink',
            field => $direction eq 'target'
            ? $LINKDIRMAP{ $args{'type'} }->{base}
            : $LINKDIRMAP{ $args{'type'} }->{target},
            new_value      => $self->uri,
            activate_scrips => !RT->config->get('LinkTransactionsRun1Scrip'),
            time_taken      => 0,
        );
        Jifty->log->error("Couldn't create transaction: $msg") unless $val;
    }

    return ( $val, $msg );
}

# }}}

# {{{ sub merge_into

=head2 merge_into

merge_into take the id of the ticket to merge this ticket into.



=cut

sub merge_into {
    my $self      = shift;
    my $ticket_id = shift;

    unless ( $self->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    # Load up the new ticket.
    my $MergeInto = RT::Model::Ticket->new( current_user => RT->system_user );
    $MergeInto->load($ticket_id);

    # make sure it exists.
    unless ( $MergeInto->id ) {
        return ( 0, _("New ticket doesn't exist") );
    }

    # Make sure the current user can modify the new ticket.
    unless ( $MergeInto->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    Jifty->handle->begin_transaction();

    # We use effective_id here even though it duplicates information from
    # the links table becasue of the massive performance hit we'd take
    # by trying to do a separate database query for merge info everytime
    # loaded a ticket.

    #update this ticket's effective id to the new ticket's id.
    my ( $id_val, $id_msg ) = $self->__set(
        column => 'effective_id',
        value  => $MergeInto->id()
    );

    unless ($id_val) {
        Jifty->handle->rollback();
        return ( 0, _("Merge failed. Couldn't set effective_id") );
    }

    if ( $self->__value('status') ne 'resolved' ) {

        my ( $status_val, $status_msg )
            = $self->__set( column => 'status', value => 'resolved' );

        unless ($status_val) {
            Jifty->handle->rollback();
            Jifty->log->error(
                _(  "%1 couldn't set status to resolved. RT's Database may be inconsistent.",
                    $self
                )
            );
            return ( 0, _("Merge failed. Couldn't set status") );
        }
    }

    # update all the links that point to that old ticket
    my $old_links_to = RT::Model::LinkCollection->new(
        current_user => $self->current_user );
    $old_links_to->limit( column => 'target', value => $self->uri );

    my %old_seen;
    while ( my $link = $old_links_to->next ) {
        if ( exists $old_seen{ $link->base . "-" . $link->type} ) {
            $link->delete;
        } elsif ( $link->base eq $MergeInto->uri ) {
            $link->delete;
        } else {

         # First, make sure the link doesn't already exist. then move it over.
            my $tmp = RT::Model::Link->new( current_user => RT->system_user );
            $tmp->load_by_cols(
                base        => $link->base,
                type        => $link->type,
                local_target => $MergeInto->id
            );
            if ( $tmp->id ) {
                $link->delete;
            } else {
                $link->set_target( $MergeInto->uri );
                $link->set_local_target( $MergeInto->id );
            }
            $old_seen{ $link->base . "-" . $link->type} = 1;
        }

    }

    my $old_links_from = RT::Model::LinkCollection->new(
        current_user => $self->current_user );
    $old_links_from->limit( column => 'base', value => $self->uri );

    while ( my $link = $old_links_from->next ) {
        if ( exists $old_seen{ $link->type. "-" . $link->target } ) {
            $link->delete;
        }
        if ( $link->target eq $MergeInto->uri ) {
            $link->delete;
        } else {

         # First, make sure the link doesn't already exist. then move it over.
            my $tmp = RT::Model::Link->new( current_user => RT->system_user );
            $tmp->load_by_cols(
                target    => $link->target,
                type      => $link->type,
                local_base => $MergeInto->id
            );
            if ( $tmp->id ) {
                $link->delete;
            } else {
                $link->set_base( $MergeInto->uri );
                $link->set_local_base( $MergeInto->id );
                $old_seen{ $link->type. "-" . $link->target } = 1;
            }
        }

    }

    # Update time fields
    foreach my $type qw(time_estimated time_worked time_left) {

        my $mutator = "set_$type";
        $MergeInto->$mutator(
            ( $MergeInto->$type() || 0 ) + ( $self->$type() || 0 ) );

    }

    #add all of this ticket's watchers to that ticket.
    foreach my $watcher_type qw(Requestors Cc AdminCc) {
        # XXX: artefact of API change
        my $method = $watcher_type;
        $method =~ s/(?<=[a-z])(?=[A-Z])/_/;
        $method = lc $method;

        my $people          = $self->$method->members_obj;
        my $addwatcher_type = $watcher_type;
        $addwatcher_type =~ s/s$//;

        while ( my $watcher = $people->next ) {

            my ( $val, $msg ) = $MergeInto->_add_watcher(
                type         => $addwatcher_type,
                silent       => 1,
                principal_id => $watcher->member_id
            );
            unless ($val) {
                Jifty->log->warn($msg);
            }
        }

    }

    #find all of the tickets that were merged into this ticket.
    my $old_mergees = RT::Model::TicketCollection->new();
    $old_mergees->limit(
        column   => 'effective_id',
        operator => '=',
        value    => $self->id
    );

    #   update their effective_id fields to the new ticket's id
    while ( my $ticket = $old_mergees->next() ) {
        my ( $val, $msg ) = $ticket->__set(
            column => 'effective_id',
            value  => $MergeInto->id()
        );
    }

    #make a new link: this ticket is merged into that other ticket.
    $self->add_link( type => 'MergedInto', target => $MergeInto->id() );

    $MergeInto->set_last_updated;

    Jifty->handle->commit();
    return ( 1, _("Merge Successful") );
}

# }}}

# }}}

# {{{ Routines dealing with ownership

# {{{ sub owner_obj

=head2 owner_obj

Takes nothing and returns an RT::Model::User object of 
this ticket's owner

=cut

sub owner_obj {
    my $self = shift;

    #If this gets ACLed, we lose on a rights check in User.pm and
    #get deep recursion. if we need ACLs here, we need
    #an equiv without ACLs

    my $owner = RT::Model::User->new();
    $owner->load( $self->__value('owner') );

    #Return the owner object
    return ($owner);
}

# }}}

# {{{ sub owner_as_string

=head2 owner_as_string

Returns the owner's email address

=cut

sub owner_as_string {
    my $self = shift;
    return ( $self->owner_obj->email );

}

# }}}

# {{{ sub set_Owner

=head2 set_owner

Takes two arguments:
     the id or name of the owner 
and  (optionally) the type of the SetOwner Transaction. It defaults
to 'Give'.  'Steal' is also a valid option.


=cut

sub set_owner {
    my $self     = shift;
    my $NewOwner = shift;
    my $Type     = shift || "Give";

    Jifty->handle->begin_transaction();

    $self->set_last_updated();  # lock the ticket
    $self->load( $self->id );   # in case $self changed while waiting for lock

    my $OldOwnerObj = $self->owner_obj;

    my $NewOwnerObj = RT::Model::User->new;
    $NewOwnerObj->load($NewOwner);
    unless ( $NewOwnerObj->id ) {
        Jifty->handle->rollback();
        return ( 0, _("That user does not exist") );
    }

    # must have ModifyTicket rights
    # or TakeTicket/StealTicket and $NewOwner is self
    # see if it's a take
    if ( $OldOwnerObj->id == RT->nobody->id ) {
        unless ( $self->current_user_has_right('ModifyTicket')
            || $self->current_user_has_right('TakeTicket') )
        {
            Jifty->handle->rollback();
            return ( 0, _("Permission Denied") );
        }
    }

    # see if it's a steal
    elsif ($OldOwnerObj->id != RT->nobody->id
        && $OldOwnerObj->id != $self->current_user->id )
    {

        unless ( $self->current_user_has_right('ModifyTicket')
            || $self->current_user_has_right('StealTicket') )
        {
            Jifty->handle->rollback();
            return ( 0, _("Permission Denied") );
        }
    } else {
        unless ( $self->current_user_has_right('ModifyTicket') ) {
            Jifty->handle->rollback();
            return ( 0, _("Permission Denied") );
        }
    }

    # If we're not stealing and the ticket has an owner and it's not
    # the current user
    if (    $Type ne 'Steal'
        and $Type ne 'Force'
        and $OldOwnerObj->id != RT->nobody->id
        and $OldOwnerObj->id != $self->current_user->id )
    {
        Jifty->handle->rollback();
        return ( 0, _("You can only take tickets that are unowned") )
            if $NewOwnerObj->id == $self->current_user->id;
        return (
            0,
            _(  "You can only reassign tickets that you own or that are unowned"
            )
        );
    }

    #If we've specified a new owner and that user can't modify the ticket
    elsif (
        !$NewOwnerObj->has_right( right => 'OwnTicket', object => $self ) )
    {
        Jifty->handle->rollback();
        return ( 0, _("That user may not own tickets in that queue") );
    }

    # If the ticket has an owner and it's the new owner, we don't need
    # To do anything
    elsif ( $NewOwnerObj->id == $OldOwnerObj->id ) {
        Jifty->handle->rollback();
        return ( 0, _("That user already owns that ticket") );
    }

    # Delete the owner in the owner group, then add a new one
    # TODO: is this safe? it's not how we really want the API to work
    # for most things, but it's fast.
    my ( $del_id, ) = $self->owner_group->members_obj->first->delete();
    unless ($del_id) {
        Jifty->handle->rollback();
        return ( 0, _("Could not change owner. ") . $del_id );
    }
    my ( $add_id, $add_msg ) = $self->owner_group->_add_member(
        principal_id      => $NewOwnerObj->principal_id,
        inside_transaction => 1
    );
    unless ($add_id) {
        Jifty->handle->rollback();
        return ( 0, _("Could not change owner. ") . $add_msg );
    }

    # We call set twice with slightly different arguments, so
    # as to not have an SQL transaction span two RT transactions

    my ($return) = $self->_set(
        column             => 'owner',
        value              => $NewOwnerObj->id,
        record_transaction => 0,
        time_taken          => 0,
        transaction_type    => $Type,
        CheckACL           => 0,                  # don't check acl
    );

    if ( ref($return) and !$return ) {
        Jifty->handle->rollback;
        return ( 0, _("Could not change owner. ") . $return );
    }

    my ( $val, $msg ) = $self->_new_transaction(
        type      => $Type,
        field     => 'owner',
        new_value => $NewOwnerObj->id,
        old_value => $OldOwnerObj->id,
        time_taken => 0,
    );

    if ($val) {
        $msg = _( "Owner changed from %1 to %2",
            $OldOwnerObj->name, $NewOwnerObj->name );
    } else {
        Jifty->handle->rollback();
        return ( 0, $msg );
    }

    Jifty->handle->commit();

    return ( $val, $msg );
}

# }}}

# {{{ sub Take

=head2 Take

A convenince method to set the ticket's owner to the current user

=cut

sub take {
    my $self = shift;
    return ( $self->set_owner( $self->current_user->id, 'Take' ) );
}

# }}}

# {{{ sub Untake

=head2 Untake

Convenience method to set the owner to 'nobody' if the current user is the owner.

=cut

sub untake {
    my $self = shift;
    return ( $self->set_owner( RT->nobody->user_object->id, 'Untake' ) );
}

# }}}

# {{{ sub Steal

=head2 Steal

A convenience method to change the owner of the current ticket to the
current user. Even if it's owned by another user.

=cut

sub steal {
    my $self = shift;

    if ( $self->is_owner( $self->current_user ) ) {
        return ( 0, _("You already own this ticket") );
    } else {
        return ( $self->set_owner( $self->current_user->id, 'Steal' ) );

    }

}

# }}}

# }}}

# {{{ Routines dealing with status

# {{{ sub validate_Status

=head2 validate_status STATUS

Takes a string. Returns true if that status is a valid status for this ticket.
Returns false otherwise.

=cut

sub validate_status {
    my $self   = shift;
    my $status = shift;

    #Make sure the status passed in is valid
    unless ( $self->queue_obj->is_valid_status($status) ) {
        return (undef);
    }

    return (1);

}

# }}}

# {{{ sub set_status

=head2 set_status STATUS

Set this ticket\'s status. STATUS can be one of: new, open, stalled, resolved, rejected or deleted.

Alternatively, you can pass in a list of named parameters (Status => STATUS, Force => FORCE).  If FORCE is true, ignore unresolved dependencies and force a status change.



=cut

sub set_status {
    my $self = shift;
    my %args;

    if ( @_ == 1 ) {
        $args{status} = shift;
    } else {
        %args = (@_);
    }

    #Check ACL
    if ( $args{status} eq 'deleted' ) {
        unless ( $self->current_user_has_right('DeleteTicket') ) {
            return ( 0, _('Permission Denied') );
        }
    } else {
        unless ( $self->current_user_has_right('ModifyTicket') ) {
            return ( 0, _('Permission Denied') );
        }
    }

    if (   !$args{Force}
        && ( $args{'status'} eq 'resolved' )
        && $self->has_unresolved_dependencies )
    {
        return ( 0, _('That ticket has unresolved dependencies') );
    }

    unless ( $self->validate_status( $args{'status'} ) ) {
        return ( 0,
            _( "'%1' is an invalid value for status", $args{'status'} ) );
    }

    my $now = RT::Date->new;
    $now->set_to_now();

    #If we're changing the status from new, record that we've started
    if ( $self->status eq 'new' && $args{status} ne 'new' ) {

        #Set the started time to "now"
        $self->_set(
            column             => 'started',
            value              => $now->iso,
            record_transaction => 0
        );
    }

    #When we close a ticket, set the 'resolved' attribute to now.
    # It's misnamed, but that's just historical.
    if ( $self->queue_obj->is_inactive_status( $args{status} ) ) {
        $self->_set(
            column             => 'resolved',
            value              => $now->iso,
            record_transaction => 0
        );
    }

    #Actually update the status
    my ( $val, $msg ) = $self->_set(
        column          => 'status',
        value           => $args{status},
        time_taken       => 0,
        CheckACL        => 0,
        transaction_type => 'status'
    );

    return ( $val, $msg );
}

# }}}

# {{{ sub delete

=head2 Delete

Takes no arguments. Marks this ticket for garbage collection

=cut

sub delete {
    my $self = shift;
    return ( $self->set_status('deleted') );

    # TODO: garbage collection
}

# }}}

# {{{ sub Stall

=head2 Stall

Sets this ticket's status to stalled

=cut

sub stall {
    my $self = shift;
    return ( $self->set_status('stalled') );
}

# }}}

# {{{ sub Reject

=head2 Reject

Sets this ticket's status to rejected

=cut

sub reject {
    my $self = shift;
    return ( $self->set_status('rejected') );
}

# }}}

# {{{ sub Open

=head2 Open

Sets this ticket\'s status to Open

=cut

sub open {
    my $self = shift;
    return ( $self->set_status('open') );
}

# }}}

# {{{ sub Resolve

=head2 Resolve

Sets this ticket\'s status to Resolved

=cut

sub resolve {
    my $self = shift;
    return ( $self->set_status('resolved') );
}

# }}}

# }}}

# {{{ Actions + Routines dealing with transactions

# {{{ sub set_Told and _setTold

=head2 set_told ISO  [TIMETAKEN]

Updates the told and records a transaction

=cut

sub set_told {
    my $self = shift;
    my $told;
    $told = shift if (@_);
    my $timetaken = shift || 0;

    unless ( $self->current_user_has_right('ModifyTicket') ) {
        return ( 0, _("Permission Denied") );
    }

    my $datetold = RT::Date->new();
    if ($told) {
        $datetold->set(
            format => 'iso',
            value  => $told
        );
    } else {
        $datetold->set_to_now();
    }

    return (
        $self->_set(
            column          => 'told',
            value           => $datetold->iso,
            time_taken       => $timetaken,
            transaction_type => 'Told'
        )
    );
}

=head2 _setTold

Updates the told without a transaction or acl check. Useful when we're sending replies.

=cut

sub _set_told {
    my $self = shift;

    my $now = RT::Date->new();
    $now->set_to_now();

    #use __set to get no ACLs ;)
    return (
        $self->__set(
            column => 'told',
            value  => $now->iso
        )
    );
}

=head2 seen_up_to


=cut

sub seen_up_to {
    my $self = shift;

    my $uid  = $self->current_user->id;
    my $attr = $self->first_attribute( "User-" . $uid . "-SeenUpTo" );
    return if $attr && $attr->content gt $self->last_updated;

    my $txns = $self->transactions;
    $txns->limit( column => 'type', value => 'comment' );
    $txns->limit( column => 'type', value => 'Correspond' );
    $txns->limit( column => 'creator', operator => '!=', value => $uid );
    $txns->limit(
        column   => 'created',
        operator => '>',
        value    => $attr->content
    ) if $attr;
    $txns->rows_per_page(1);
    return $txns->first;
}

# }}}

=head2 transaction_batch

  Returns an array reference of all transactions created on this ticket during
  this ticket object's lifetime, or undef if there were none.

  Only works when the C<Usetransaction_batch> config option is set to true.

=cut

sub transaction_batch {
    my $self = shift;
    return $self->{_transaction_batch};
}

sub DESTROY {
    my $self = shift;

    # DESTROY methods need to localize $@, or it may unset it.  This
    # causes $m->abort to not bubble all of the way up.  See perlbug
    # http://rt.perl.org/rt3/Ticket/Display.html?id=17650
    local $@;

    # The following line eliminates reentrancy.
    # It protects against the fact that perl doesn't deal gracefully
    # when an object's refcount is changed in its destructor.
    return if $self->{_Destroyed}++;

    my $batch = $self->transaction_batch or return;
    return unless @$batch;

    require RT::Model::ScripCollection;
    RT::Model::ScripCollection->new( current_user => RT->system_user )->apply(
        stage           => 'transaction_batch',
        ticket_obj      => $self,
        transaction_obj => $batch->[0],
        type            => join( ',', ( map { $_->type } @{$batch} ) )
    );
}

# }}}

# {{{ PRIVATE UTILITY METHODS. Mostly needed so Ticket can be a DBIx::Record

# {{{ sub _OverlayAccessible

sub _overlay_accessible {
    {   effective_id      => { 'read' => 1, 'write' => 1, 'public' => 1 },
        queue            => { 'read' => 1, 'write' => 1 },
        Requestors       => { 'read' => 1, 'write' => 1 },
        owner            => { 'read' => 1, 'write' => 1 },
        subject          => { 'read' => 1, 'write' => 1 },
        initial_priority => { 'read' => 1, 'write' => 1 },
        final_priority   => { 'read' => 1, 'write' => 1 },
        priority         => { 'read' => 1, 'write' => 1 },
        status           => { 'read' => 1, 'write' => 1 },
        time_estimated   => { 'read' => 1, 'write' => 1 },
        time_worked      => { 'read' => 1, 'write' => 1 },
        time_left        => { 'read' => 1, 'write' => 1 },
        told             => { 'read' => 1, 'write' => 1 },
        resolved         => { 'read' => 1 },
        type             => { 'read' => 1 },
        starts        => { 'read' => 1, 'write' => 1 },
        started       => { 'read' => 1, 'write' => 1 },
        due           => { 'read' => 1, 'write' => 1 },
        creator       => { 'read' => 1, 'auto'  => 1 },
        created       => { 'read' => 1, 'auto'  => 1 },
        last_updated_by => { 'read' => 1, 'auto'  => 1 },
        last_updated   => { 'read' => 1, 'auto'  => 1 }
    };

}

# }}}

# {{{ sub _set

sub _set {
    my $self = shift;

    my %args = (
        column             => undef,
        value              => undef,
        time_taken          => 0,
        record_transaction => 1,
        UpdateTicket       => 1,
        CheckACL           => 1,
        transaction_type    => 'Set',
        @_
    );

    if ( $args{'CheckACL'} ) {
        unless ( $self->current_user_has_right('ModifyTicket') ) {
            return ( 0, _("Permission Denied") );
        }
    }

    unless ( $args{'UpdateTicket'} || $args{'record_transaction'} ) {
        Jifty->log->error(
            "Ticket->_set called without a mandate to record an update or update the ticket"
        );
        return ( 0, _("Internal Error") );
    }

    #if the user is trying to modify the record

    #Take care of the old value we really don't want to get in an ACL loop.
    # so ask the super::_value
    my $Old = $self->SUPER::_value( $args{'column'} );

    if ( $Old && $args{'value'} && $Old eq $args{'value'} ) {

        return ( 0, _("That is already the current value") );
    }
    my ($return);
    if ( $args{'UpdateTicket'} ) {

        #Set the new value
        my $return = $self->SUPER::_set(
            column => $args{'column'},
            value  => $args{'value'}
        );

        #If we can't actually set the field to the value, don't record
        # a transaction. instead, get out of here.
        if ( $return->errno ) {
            return ($return);
        }
    }
    if ( $args{'record_transaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_new_transaction(
            type      => $args{'transaction_type'},
            field     => $args{'column'},
            new_value => $args{'value'},
            old_value => $Old,
            time_taken => $args{'time_taken'},
        );
        return ( $Trans, scalar $TransObj->brief_description );
    } else {
        return ($return);
    }
}

# }}}

# {{{ sub _value

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {

    my $self   = shift;
    my $column = shift;

    #if the column is public, return it.
    if (1) {    # $self->_accessible( $column, 'public' ) ) {

        #Jifty->log->debug("Skipping ACL check for $column\n");
        return ( $self->SUPER::_value($column) );

    }

    #If the current user doesn't have ACLs, don't let em at it.

    unless ( $self->current_user_has_right('ShowTicket') ) {
        return (undef);
    }
    return ( $self->SUPER::_value($column) );

}

# }}}

# {{{ sub _update_time_taken

=head2 _update_time_taken

This routine will increment the time_worked counter. it should
only be called from _new_transaction 

=cut

sub _update_time_taken {
    my $self    = shift;
    my $Minutes = shift;
    my ($Total);

    $Total = $self->SUPER::_value("time_worked");
    $Total = ( $Total || 0 ) + ( $Minutes || 0 );
    $self->SUPER::_set(
        column => "time_worked",
        value  => $Total
    );

    return ($Total);
}

# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub current_user_has_right

=head2 current_user_has_right

  Takes the textual name of a Ticket scoped right (from RT::Model::ACE) and returns
1 if the user has that right. It returns 0 if the user doesn't have that right.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;

    return $self->current_user->principal_object->has_right(
        object => $self,
        right  => $right,
    );
}

# }}}

# {{{ sub has_right

=head2 has_right

 Takes a paramhash with the attributes 'right' and 'principal'
  'right' is a ticket-scoped textual right from RT::Model::ACE 
  'principal' is an RT::Model::User object

  Returns 1 if the principal has the right. Returns undef if not.

=cut

sub has_right {
    my $self = shift;
    my %args = (
        right     => undef,
        principal => undef,
        @_
    );

    unless (( defined $args{'principal'} )
        and ( ref( $args{'principal'} ) ) )
    {
        Carp::cluck("Principal attrib undefined for Ticket::has_right");
        Jifty->log->fatal("Principal attrib undefined for Ticket::has_right");
        return (undef);
    }

    return (
        $args{'principal'}->has_right(
            object => $self,
            right  => $args{'right'}
        )
    );
}

# }}}

# }}}

=head2 Reminders

Return the Reminders object for this ticket. (It's an RT::Reminders object.)
It isn't acutally a searchbuilder collection itself.

=cut

sub reminders {
    my $self = shift;

    unless ( $self->{'__reminders'} ) {
        $self->{'__reminders'} = RT::Reminders->new;
        $self->{'__reminders'}->ticket( $self->id );
    }
    return $self->{'__reminders'};

}

# {{{ sub Transactions

=head2 Transactions

  Returns an RT::Model::TransactionCollection object of all transactions on this ticket

=cut

sub transactions {
    my $self = shift;

    my $transactions = RT::Model::TransactionCollection->new;

    #If the user has no rights, return an empty object
    if ( $self->current_user_has_right('ShowTicket') ) {
        $transactions->limit_to_ticket( $self->id );

        # if the user may not see comments do not return them
        unless ( $self->current_user_has_right('ShowTicketcomments') ) {
            $transactions->limit(
                subclause => 'acl',
                column    => 'type',
                operator  => '!=',
                value     => "comment"
            );
            $transactions->limit(
                subclause        => 'acl',
                column           => 'type',
                operator         => '!=',
                value            => "commentEmailRecord",
                entry_aggregator => 'AND'
            );

        }
    }

    return ($transactions);
}

# }}}

# {{{ transaction_custom_fields

=head2 transaction_custom_fields

    Returns the custom fields that transactions on tickets will have.

=cut

sub transaction_custom_fields {
    my $self = shift;
    return $self->queue_obj->ticket_transaction_custom_fields;
}

# }}}

# {{{ sub custom_field_values

=head2 custom_field_values

# Do name => id mapping (if needed) before falling back to
# RT::Record's custom_field_values

See L<RT::Record>

=cut

sub custom_field_values {
    my $self  = shift;
    my $field = shift;
    if ( $field and $field !~ /^\d+$/ ) {
        my $cf = RT::Model::CustomField->new;
        $cf->load_by_name_and_queue( name => $field, queue => $self->queue );
        unless ( $cf->id ) {
            $cf->load_by_name_and_queue( name => $field, queue => 0 );
        }
        unless ( $cf->id ) {

            # If we didn't find a valid cfid, give up.
            return RT::Model::CustomFieldValueCollection->new;
        }
    }
    return $self->SUPER::custom_field_values($field);
}

# }}}

# {{{ sub custom_field_lookup_type

=head2 custom_field_lookup_type

Returns the RT::Model::Ticket lookup type, which can be passed to 
RT::Model::CustomField->create() via the 'lookup_type' hash key.

=cut

# }}}

sub custom_field_lookup_type {
    "RT::Model::Queue-RT::Model::Ticket";
}

=head2 ACLEquivalenceobjects

This method returns a list of objects for which a user's rights also apply
to this ticket. Generally, this is only the ticket's queue, but some RT 
extensions may make other objects availalbe too.

This method is called from L<RT::Model::Principal/has_right>.

=cut

sub acl_equivalence_objects {
    my $self = shift;
    return $self->queue_obj;

}

1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=cut

