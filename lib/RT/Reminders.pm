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

package RT::Reminders;

use strict;
use warnings;

use base 'RT::Base';

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->CurrentUser(@_);
    return($self);
}

sub Ticket {
    my $self = shift;
    $self->{'_ticket'} = shift if (@_);
    return ($self->{'_ticket'});
}

sub TicketObj {
    my $self = shift;
    unless ($self->{'_ticketobj'}) {
        $self->{'_ticketobj'} = RT::Ticket->new($self->CurrentUser);
        $self->{'_ticketobj'}->Load($self->Ticket);
    }
    return $self->{'_ticketobj'};
}

=head2 Collection

Returns an RT::Tickets object containing reminders for this object's "Ticket"

=cut

sub Collection {
    my $self = shift;
    my $col = RT::Tickets->new($self->CurrentUser);

    my $query = 'Type = "reminder" AND RefersTo = "'.$self->Ticket.'"';

    $col->FromSQL($query);

    $col->OrderByCols( { FIELD => 'Due' }, { FIELD => 'id' } );

    return($col);
}

=head2 Add

Add a reminder for this ticket.

Takes

    Subject
    Owner
    Due

=cut

sub Add {
    my $self = shift;
    my %args = (
        Subject => undef,
        Owner => undef,
        Due => undef,
        @_
    );

    my $ticket = RT::Ticket->new($self->CurrentUser);
    $ticket->Load($self->Ticket);
    if ( !$ticket->id ) {
        return ( 0, $self->loc( "Failed to load ticket [_1]", $self->Ticket ) );
    }

    if ( lc $ticket->Status eq 'deleted' ) {
        return ( 0, $self->loc("Can't link to a deleted ticket") );
    }

    return ( 0, $self->loc('Permission Denied') )
      unless $self->CurrentUser->HasRight(
        Right  => 'CreateTicket',
        Object => $self->TicketObj->QueueObj,
      )
      && $self->CurrentUser->HasRight(
        Right  => 'ModifyTicket',
        Object => $self->TicketObj,
      );

    my $reminder = RT::Ticket->new($self->CurrentUser);
    # the 2nd return value is txn id, which is useless here
    my ( $status, undef, $msg ) = $reminder->Create(
        Subject => $args{'Subject'},
        Owner => $args{'Owner'},
        Due => $args{'Due'},
        RefersTo => $self->Ticket,
        Type => 'reminder',
        Queue => $self->TicketObj->Queue,
        Status => $self->TicketObj->QueueObj->LifecycleObj->ReminderStatusOnOpen,
    );
    $self->TicketObj->_NewTransaction(
        Type => 'AddReminder',
        Field => 'RT::Ticket',
        NewValue => $reminder->id
    ) if $status;
    return ( $status, $msg );
}

sub Open {
    my $self = shift;
    my $reminder = shift;

    my ( $status, $msg ) =
      $reminder->SetStatus( $reminder->LifecycleObj->ReminderStatusOnOpen );
    $self->TicketObj->_NewTransaction(
        Type => 'OpenReminder',
        Field => 'RT::Ticket',
        NewValue => $reminder->id
    ) if $status;
    return ( $status, $msg );
}

sub Resolve {
    my $self = shift;
    my $reminder = shift;
    my ( $status, $msg ) =
      $reminder->SetStatus( $reminder->LifecycleObj->ReminderStatusOnResolve );
    $self->TicketObj->_NewTransaction(
        Type => 'ResolveReminder',
        Field => 'RT::Ticket',
        NewValue => $reminder->id
    ) if $status;
    return ( $status, $msg );
}

RT::Base->_ImportOverlays();

1;
