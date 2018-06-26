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

use strict;
use warnings;

package RT::Action::SLA_SetDue;

use base qw(RT::Action::SLA);

=head2 Prepare

Checks if the ticket has service level defined.

=cut

sub Prepare {
    my $self = shift;

    unless ( $self->TicketObj->SLA ) {
        $RT::Logger->error('SLA::SetDue scrip has been applied to ticket #'
            . $self->TicketObj->id . ' that has no SLA defined');
        return 0;
    }

    return 1;
}

=head2 Commit

Set the Due date accordingly to SLA.

=cut

sub Commit {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $txn = $self->TransactionObj;
    my $level = $ticket->SLA;

    my ($last_reply, $is_outside) = $self->LastEffectiveAct;
    $RT::Logger->debug(
        'Last effective '. ($is_outside? '':'non-') .'outside actors\' reply'
        .' to ticket #'. $ticket->id .' is txn #'. $last_reply->id
    );

    my $response_due = $self->Due(
        Ticket => $ticket,
        Level => $level,
        Type => $is_outside? 'Response' : 'KeepInLoop',
        Time => $last_reply->CreatedObj->Unix,
    );

    my $resolve_due = $self->Due(
        Ticket => $ticket,
        Level => $level,
        Type => 'Resolve',
        Time => $ticket->CreatedObj->Unix,
    );

    my $due;
    $due = $response_due if defined $response_due;
    $due = $resolve_due unless defined $due;
    $due = $resolve_due if defined $due && defined $resolve_due && $resolve_due < $due;

    return $self->SetDateField( Due => $due );
}

sub IsOutsideActor {
    my $self = shift;
    my $txn = shift || $self->TransactionObj;

    my $actor = $txn->CreatorObj->PrincipalObj;

    # owner is always treated as inside actor
    return 0 if $actor->id == $self->TicketObj->Owner;

    if ( RT->Config->Get('ServiceAgreements')->{'AssumeOutsideActor'} ) {
        # All non-admincc users are outside actors
        return 0 if $self->TicketObj          ->AdminCc->HasMemberRecursively( $actor )
                 or $self->TicketObj->QueueObj->AdminCc->HasMemberRecursively( $actor );

        return 1;
    } else {
        # Only requestors are outside actors
        return 1 if $self->TicketObj->Requestors->HasMemberRecursively( $actor );
        return 0;
    }
}

sub LastEffectiveAct {
    my $self = shift;

    my $txns = $self->TicketObj->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    $txns->Limit( FIELD => 'Type', VALUE => 'Create' );
    $txns->OrderByCols(
        { FIELD => 'Created', ORDER => 'DESC' },
        { FIELD => 'id', ORDER => 'DESC' },
    );

    my $res;
    while ( my $txn = $txns->Next ) {
        unless ( $self->IsOutsideActor( $txn ) ) {
            last if $res;
            return ($txn);
        }
        $res = $txn;
    }
    return ($res, 1);
}

1;
