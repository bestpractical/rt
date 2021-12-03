# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Action::CreateEventSLAViolation;

use base qw(RT::Action);

=head2 Prepare

Checks if the ticket has service level defined.

=cut

sub Prepare {
    my $self = shift;

    my $ticket = $self->TicketObj;

    for my $field (qw/SLA Due/) {
        if ( !$ticket->$field ) {
            RT->Logger->error( 'CreateEventSLAViolation scrip has been applied to ticket #'
                    . $ticket->Id
                    . " that has no $field defined" );
            return 0;
        }
    }

    if ( $ticket->DueObj->Diff > 0 ) {
        RT->Logger->error(
            'CreateEventSLAViolation scrip has been applied to ticket #' . $ticket->Id . ' that is not overdue' );
        return 0;
    }

    if ( $ticket->LifecycleObj->IsInactive( $ticket->Status ) ) {
        RT->Logger->error(
            'CreateEventSLAViolation scrip has been applied to ticket #' . $ticket->Id . ' that is inactive' );
        return 0;
    }

    # Don't repetitively create the event.
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type',     VALUE => 'Event' );
    $txns->Limit( FIELD => 'Field',    VALUE => 'SLAViolation' );
    $txns->Limit( FIELD => 'NewValue', VALUE => $ticket->Due );
    $txns->OrderByCols( { FIELD => 'id', ORDER => 'DESC' } );
    return 0 if $txns->First;
    return 1;
}

=head2 Commit

Set the Due date accordingly to SLA.

=cut

sub Commit {
    my $self = shift;
    $self->TicketObj->_NewTransaction(
        Type     => 'Event',
        Field    => 'SLAViolation',
        OldValue => $self->TicketObj->SLA,
        NewValue => $self->TicketObj->Due,
    );
    return;
}

1;
