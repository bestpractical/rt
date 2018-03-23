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

package RT::Action::AutoOpen;

use strict;
use warnings;
use base qw(RT::Action);

=head1 DESCRIPTION

This action automatically moves a ticket to an active status.

Status is not changed if there is no active statuses in the lifecycle.

Status is not changed if the current status is first active for ticket's status
lifecycle. For example if ticket's status is 'processing' and active statuses are
'processing', 'on hold' and 'waiting' then status is not changed, but for ticket
with status 'on hold' other rules are checked.

Status is not changed if it's in the list of C<initial> statuses for the
current scheme and creator of the current transaction
is one of the ticket's requestors.

Status is not changed if message's head has field C<RT-Control> with C<no-autoopen>
substring.

Status is set to the first possible active status. If the ticket's
status is C<Stalled> then RT finds all possible transitions from C<Stalled>
status and selects first one that results in the ticket having an
active status.

=cut

sub Prepare {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $next = $ticket->FirstActiveStatus;
    return 1 unless defined $next;

    # no change if the ticket is in initial status and the message is a mail
    # from a requestor
    return 1 if $ticket->LifecycleObj->IsInitial($ticket->Status)
        && $self->TransactionObj->IsInbound;

    if ( my $msg = $self->TransactionObj->Message->First ) {
        return 1 if ($msg->GetHeader('RT-Control') || '') =~ /\bno-autoopen\b/i;
    }

    $self->{'set_status_to'} = $next;

    return 1;
}

sub Commit {
    my $self = shift;

    return 1 unless my $new_status = $self->{'set_status_to'};

    my ($val, $msg) = $self->TicketObj->SetStatus( $new_status );
    unless ( $val ) {
        $RT::Logger->error( "Couldn't auto-open ticket: ". $msg );
        return 0;
    }
    return 1;
}

RT::Base->_ImportOverlays();

1;
