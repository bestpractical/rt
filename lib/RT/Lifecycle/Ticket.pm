# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Lifecycle::Ticket;

use base qw(RT::Lifecycle);

=head2 Queues

Returns L<RT::Queues> collection with queues that use this lifecycle.

=cut

sub Queues {
    my $self = shift;
    require RT::Queues;
    my $queues = RT::Queues->new( RT->SystemUser );
    $queues->Limit( FIELD => 'Lifecycle', VALUE => $self->Name );
    return $queues;
}

=head3 DefaultOnMerge

Returns the status that should be used when tickets
are merged.

=cut

sub DefaultOnMerge {
    my $self = shift;
    return $self->DefaultStatus('on_merge');
}

=head3 ReminderStatusOnOpen

Returns the status that should be used when reminders are opened.

=cut

sub ReminderStatusOnOpen {
    my $self = shift;
    return $self->DefaultStatus('reminder_on_open') || 'open';
}

=head3 ReminderStatusOnResolve

Returns the status that should be used when reminders are resolved.

=cut

sub ReminderStatusOnResolve {
    my $self = shift;
    return $self->DefaultStatus('reminder_on_resolve') || 'resolved';
}

=head2 RegisterRights

Ticket lifecycle rights are registered (and thus grantable) at the queue
level.

=cut

sub RegisterRights {
    my $self = shift;

    my %rights = $self->RightsDescription( 'ticket' );

    require RT::ACE;

    while ( my ($right, $description) = each %rights ) {
        next if RT::ACE->CanonicalizeRightName( $right );

        RT::Queue->AddRight( Status => $right => $description );
    }
}

1;
