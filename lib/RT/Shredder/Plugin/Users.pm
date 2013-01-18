# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::Shredder::Plugin::Users;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

=head1 NAME

RT::Shredder::Plugin::Users - search plugin for wiping users.

=head1 ARGUMENTS

=head2 status - string

Status argument allow you to limit result set to C<disabled>,
C<enabled> or C<any> users.
B<< Default value is C<disabled>. >>

=head2 name - mask

User name mask.

=head2 email - mask

Email address mask.

=head2 member_of - group identifier

Using this option users that are members of a particular group can
be selected for deletion. Identifier is name of user defined group
or id of a group, as well C<Privileged> or <unprivileged> can used
to select people from system groups.

=head2 replace_relations - user identifier

When you delete user there are could be minor links to him in RT DB.
This option allow you to replace this links with link to other user.
This links are Creator and LastUpdatedBy, but NOT any watcher roles,
this means that if user is watcher(Requestor, Owner,
Cc or AdminCc) of the ticket or queue then link would be deleted.

This argument could be user id or name.

=head2 no_tickets - boolean

If true then plugin looks for users who are not watchers (Owners,
Requestors, Ccs or AdminCcs) of any ticket.

Before RT 3.8.5, users who were watchers of deleted tickets B<will be deleted>
when this option was enabled. Decision has been made that it's not correct
and you should either shred these deleted tickets, change watchers or
explicitly delete user by name or email.

Note that found users still B<may have relations> with other objects,
for example via Creator or LastUpdatedBy fields, and you most probably
want to use C<replace_relations> option.

=cut

sub SupportArgs
{
    return $_[0]->SUPER::SupportArgs,
           qw(status name email member_of replace_relations no_tickets);
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    if( $args{'status'} ) {
        unless( $args{'status'} =~ /^(disabled|enabled|any)$/i ) {
            return (0, "Status '$args{'status'}' is unsupported.");
        }
    } else {
        $args{'status'} = 'disabled';
    }
    if( $args{'email'} ) {
        $args{'email'} = $self->ConvertMaskToSQL( $args{'email'} );
    }
    if( $args{'name'} ) {
        $args{'name'} = $self->ConvertMaskToSQL( $args{'name'} );
    }
    if( $args{'member_of'} ) {
        my $group = RT::Group->new( RT->SystemUser );
        if ( $args{'member_of'} =~ /^(Everyone|Privileged|Unprivileged)$/i ) {
            $group->LoadSystemInternalGroup( $args{'member_of'} );
        }
        else {
            $group->LoadUserDefinedGroup( $args{'member_of'} );
        }
        unless ( $group->id ) {
            return (0, "Couldn't load group '$args{'member_of'}'" );
        }
        $args{'member_of'} = $group->id;

    }
    if( $args{'replace_relations'} ) {
        my $uid = $args{'replace_relations'};
        # XXX: it's possible that SystemUser is not available
        my $user = RT::User->new( RT->SystemUser );
        $user->Load( $uid );
        unless( $user->id ) {
            return (0, "Couldn't load user '$uid'" );
        }
        $args{'replace_relations'} = $user->id;
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my %args = ( Shredder => undef, @_ );
    my $objs = RT::Users->new( RT->SystemUser );
    # XXX: we want preload only things we need, but later while
    # logging we need all data, TODO envestigate this
    # $objs->Columns(qw(id Name EmailAddress Lang Timezone
    #                   Creator Created LastUpdated LastUpdatedBy));
    if( my $s = $self->{'opt'}{'status'} ) {
        if( $s eq 'any' ) {
            $objs->FindAllRows;
        } elsif( $s eq 'disabled' ) {
            $objs->LimitToDeleted;
        } else {
            $objs->LimitToEnabled;
        }
    }
    if( $self->{'opt'}{'email'} ) {
        $objs->Limit( FIELD => 'EmailAddress',
                  OPERATOR => 'MATCHES',
                  VALUE => $self->{'opt'}{'email'},
                );
    }
    if( $self->{'opt'}{'name'} ) {
        $objs->Limit( FIELD => 'Name',
                  OPERATOR => 'MATCHES',
                  VALUE => $self->{'opt'}{'name'},
                );
    }
    if( $self->{'opt'}{'member_of'} ) {
        $objs->MemberOfGroup( $self->{'opt'}{'member_of'} );
    }
    if( $self->{'opt'}{'no_tickets'} ) {
        return $self->FilterWithoutTickets(
            Shredder => $args{'Shredder'},
            Objects  => $objs,
        );
    } else {
        if( $self->{'opt'}{'limit'} ) {
            $objs->RowsPerPage( $self->{'opt'}{'limit'} );
        }
    }
    return (1, $objs);
}

sub SetResolvers
{
    my $self = shift;
    my %args = ( Shredder => undef, @_ );

    if( $self->{'opt'}{'replace_relations'} ) {
        my $uid = $self->{'opt'}{'replace_relations'};
        my $resolver = sub {
            my %args = (@_);
            my $t =    $args{'TargetObject'};
            foreach my $method ( qw(Creator LastUpdatedBy) ) {
                next unless $t->_Accessible( $method => 'read' );
                $t->__Set( Field => $method, Value => $uid );
            }
# we might need to change more on a transaction object
            if ( $t->_Accessible('OldValue' => 'read') ) {
                if ( defined $t->OldValue && $t->OldValue eq $args{'BaseObject'}->id ) {
                    $t->__Set( Field => 'OldValue', Value => $uid );
                }
                elsif ( defined $t->NewValue && $t->NewValue eq $args{'BaseObject'}->id ) {
                    $t->__Set( Field => 'NewValue', Value => $uid );
                }
            }
        };
        $args{'Shredder'}->PutResolver( BaseClass => 'RT::User', Code => $resolver );
    }
    return (1);
}

sub FilterWithoutTickets {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Objects  => undef,
        @_,
    );
    my $users = $args{Objects};
    $self->FetchNext( $users, 'init' );

    my @res;
    while ( my $user = $self->FetchNext( $users ) ) {
        push @res, $user if $self->_WithoutTickets( $user );
        return (1, \@res) if $self->{'opt'}{'limit'} && @res >= $self->{'opt'}{'limit'};
    }
    return (1, \@res);
}

sub _WithoutTickets {
    my ($self, $user) = @_;
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->{'allow_deleted_search'} = 1;
    $tickets->FromSQL( 'Watcher.id = '. $user->id );
    # HACK: we may use Count method which counts all records
    # that match condtion, but we really want to know only that
    # at least one record exist, so we fetch first row only
    $tickets->RowsPerPage(1);
    return !$tickets->First;
}

1;
