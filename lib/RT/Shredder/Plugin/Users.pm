# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

=head2 not_member_of - group identifier

Like member_of, but selects users who are not members of the provided
group.

=head2 replace_relations - user identifier

When you delete a user there could be minor links to them in the RT database.
This option allow you to replace these links with links to the new user.
The replaceable links are Creator and LastUpdatedBy, but NOT any watcher roles.
This means that if the user is a watcher(Requestor, Owner,
Cc or AdminCc) of the ticket or queue then the link would be deleted.

This argument could be a user id or name.

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

=head2 no_ticket_transactions - boolean

If true then plugin looks for users who have created no ticket transactions.
This is especially useful after wiping out tickets.

Note that found users still B<may have relations> with other objects,
for example via Creator or LastUpdatedBy fields, and you most probably
want to use C<replace_relations> option.

=cut

sub SupportArgs
{
    return $_[0]->SUPER::SupportArgs,
           qw(status name email member_of not_member_of replace_relations no_tickets no_ticket_transactions);
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
    if( $args{'member_of'} or $args{'not_member_of'} ) {
        foreach my $group_option ( qw(member_of not_member_of) ){
            next unless $args{$group_option};

            my $group = RT::Group->new( RT->SystemUser );
            if ( $args{$group_option} =~ /^(Everyone|Privileged|Unprivileged)$/i ) {
                $group->LoadSystemInternalGroup( $args{$group_option} );
            }
            else {
                $group->LoadUserDefinedGroup( $args{$group_option} );
            }
            unless ( $group->id ) {
                return (0, "Couldn't load group '$args{$group_option}'" );
            }
            $args{$group_option} = $group->id;
        }
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
                  CASESENSITIVE => 0,
                );
    }
    if( $self->{'opt'}{'member_of'} ) {
        $objs->MemberOfGroup( $self->{'opt'}{'member_of'} );
    }
    my @filter;
    if( $self->{'opt'}{'not_member_of'} ) {
        push @filter, $self->FilterNotMemberOfGroup(
            Shredder => $args{'Shredder'},
            GroupId  => $self->{'opt'}{'not_member_of'},
        );
    }
    if( $self->{'opt'}{'no_tickets'} ) {
        push @filter, $self->FilterWithoutTickets(
            Shredder => $args{'Shredder'},
        );
    }
    if( $self->{'opt'}{'no_ticket_transactions'} ) {
        push @filter, $self->FilterWithoutTicketTransactions(
            Shredder => $args{'Shredder'},
        );
    }

    if (@filter) {
        $self->FetchNext( $objs, 'init' );
        my @res;
        USER: while ( my $user = $self->FetchNext( $objs ) ) {
            for my $filter (@filter) {
                next USER unless $filter->($user);
            }
            push @res, $user;
            last if $self->{'opt'}{'limit'} && @res >= $self->{'opt'}{'limit'};
        }
        $objs = \@res;
    } elsif ( $self->{'opt'}{'limit'} ) {
        $objs->RowsPerPage( $self->{'opt'}{'limit'} );
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
        };
        $args{'Shredder'}->PutResolver( BaseClass => 'RT::User', Code => $resolver );
    }
    return (1);
}

sub FilterNotMemberOfGroup {
    my $self = shift;
    my %args = (
        Shredder => undef,
        GroupId  => undef,
        @_,
    );

    my $group = RT::Group->new(RT->SystemUser);
    $group->Load($args{'GroupId'});

    return sub {
        my $user = shift;
        not $group->HasMemberRecursively($user->id);
    };
}

sub FilterWithoutTickets {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Objects  => undef,
        @_,
    );

    return sub {
        my $user = shift;
        $self->_WithoutTickets( $user )
    };
}

sub _WithoutTickets {
    my ($self, $user) = @_;
    return unless $user and $user->Id;
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->{'allow_deleted_search'} = 1;
    $tickets->FromSQL( 'Watcher.id = '. $user->id );

    # we could use the Count method which counts all records
    # that match, but we really want to know only that
    # at least one record exists, so this is faster
    $tickets->RowsPerPage(1);
    return !$tickets->First;
}

sub FilterWithoutTicketTransactions {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Objects  => undef,
        @_,
    );

    return sub {
        my $user = shift;
        $self->_WithoutTicketTransactions( $user )
    };
}

sub _WithoutTicketTransactions {
    my ($self, $user) = @_;
    return unless $user and $user->Id;
    my $txns = RT::Transactions->new( RT->SystemUser );
    $txns->Limit(FIELD => 'ObjectType', VALUE => 'RT::Ticket');
    $txns->Limit(FIELD => 'Creator', VALUE => $user->Id);

    # we could use the Count method which counts all records
    # that match, but we really want to know only that
    # at least one record exists, so this is faster
    $txns->RowsPerPage(1);
    return !$txns->First;
}

1;
