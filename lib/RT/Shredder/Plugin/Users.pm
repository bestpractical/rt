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

=head2 replace_relations - user identifier

When you delete user there is could be minor links to him in RT DB.
This option allow you to replace this links with link to other user.
This links are Creator and LastUpdatedBy, but NOT any watcher roles,
this mean that if user is watcher(Requestor, Owner,
Cc or AdminCc) of the ticket or queue then link would be deleted.

This argument could be user id or name.

=head2 no_tickets - boolean

If true then plugin looks for users who are not watchers (Owners,
Requestors, Ccs or AdminCcs) of any ticket.

B<Note> that found users still may have relations with other objects
and you most probably want to use C<replace_relations> option.

=cut

sub SupportArgs
{
    return $_[0]->SUPER::SupportArgs,
           qw(status name email replace_relations no_tickets);
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
    if( $args{'replace_relations'} ) {
        my $uid = $args{'replace_relations'};
        # XXX: it's possible that SystemUser is not available
        my $user = RT::Model::User->new( $RT::SystemUser );
        $user->load( $uid );
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
    my $objs = RT::Model::Users->new( $RT::SystemUser );
    # XXX: we want preload only things we need, but later while
    # logging we need all data, TODO envestigate this
    # $objs->columns(qw(id Name EmailAddress Lang Timezone
    #                   Creator Created LastUpdated LastUpdatedBy));
    if( my $s = $self->{'opt'}{'status'} ) {
        if( $s eq 'any' ) {
            $objs->{'find_disabled_rows'} = 1;
        } elsif( $s eq 'disabled' ) {
            $objs->{'find_disabled_rows'} = 1;
            $objs->limit(
                alias => $objs->PrincipalsAlias,
                column    => 'Disabled',
                operator => '!=',
                value    => '0',
            );
        } else {
            $objs->LimitToEnabled;
        }
    }
    if( $self->{'opt'}{'email'} ) {
        $objs->limit( column => 'EmailAddress',
                  operator => 'MATCHES',
                  value => $self->{'opt'}{'email'},
                );
    }
    if( $self->{'opt'}{'name'} ) {
        $objs->limit( column => 'Name',
                  operator => 'MATCHES',
                  value => $self->{'opt'}{'name'},
                );
    }

    if( $self->{'opt'}{'no_tickets'} ) {
        return $self->FilterWithoutTickets(
            Shredder => $args{'Shredder'},
            Objects  => $objs,
        );
    } else {
        if( $self->{'opt'}{'limit'} ) {
            $objs->rows_per_page( $self->{'opt'}{'limit'} );
        }
    }
    return (1, $objs);
}

sub set_Resolvers
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
                $t->__set( column => $method, value => $uid );
            }
        };
        $args{'Shredder'}->PutResolver( BaseClass => 'RT::Model::User', Code => $resolver );
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
    my $tickets = RT::Model::TicketCollection->new( $RT::SystemUser );
    $tickets->from_sql( 'Watcher.id = '. $user->id );
    # HACK: we may use Count method which counts all records
    # that match condtion, but we really want to know only that
    # at least one record exist, so we fetch first row only
    $tickets->rows_per_page(1);
    return !$tickets->first;
}

1;
