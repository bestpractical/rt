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

package RT::Action::UpdateParentTimeWorked;
use base 'RT::Action';

=head1 NAME

RT::Action::UpdateParentTimeWorked - RT's scrip action to set/update the time
worked on a parent ticket when a child ticket's TimeWorked is added to.

=head1 DESCRIPTION

This action is used as an action for the 'On TimeWorked Change' condition.

When it fires it finds a ticket's parent tickets and increments the Time Worked
value on those tickets along with the built-in behavior of incrementing Time
Worked on the current ticket.

=head2 Important Notes on Operation

There are some important details related to the use of this scrip for time
tracking that you should take into account when using it.

=over

=item * Parent and child time entries are combined on the parent

This is the intended function of the scrip, but since the parent ticket has
only one Time Worked value, it is difficult to differentiate time recorded
directly on the parent ticket from time added from child tickets. If you record
time only on child tickets, this is typically not an issue. If you record time
on the parent ticket in addition to child tickets, it can make it difficult to
pull out the time specifically logged on the parent.

=item * A ticket must be linked as a child when the time is recorded

For this scrip to work properly, a ticket must be linked to the parent as
a child before time is entered. If you link a child ticket to a parent
and it already has time recorded, that time will not be added to the parent.
Similarly, if you remove a child ticket link from a parent, any previously
recorded time will remain in the parent's Time Worked value. If you want the
time removed, you must subtract it manually.

=back

RT has a feature called C<$DisplayTotalTimeWorked> that you can activate in
your C<RT_SiteConfig.pm> file. This feature dynamically calculates time
worked on child tickets and shows it on the parent. This solves the issues
above because it doesn't modify the parent's Time Worked value and it will
update if children tickets are added or removed.

=cut

sub Prepare {
    my $self = shift;
    my $ticket = $self->TicketObj;
    return 0 unless $ticket->MemberOf->Count;
    return 1;
}

sub Commit {
    my $self   = shift;
    my $ticket = $self->TicketObj;
    my $txn    = $self->TransactionObj;

    my $parents     = $ticket->MemberOf;
    my $time_worked = $txn->TimeTaken
      || ( $txn->NewValue - $txn->OldValue );

    while ( my $parent = $parents->Next ) {
        my $parent_ticket = $parent->TargetObj;
        my $original_actor = RT::CurrentUser->new( $txn->Creator );
        my $actor_parent_ticket = RT::Ticket->new( $original_actor );
        $actor_parent_ticket->Load( $parent_ticket->Id );
        unless ( $actor_parent_ticket->Id ) {
            RT->Logger->error("Unable to load ".$parent_ticket->Id." as ".$txn->Creator->Name);
            return 0;
        }
        my ( $ret, $msg ) = $actor_parent_ticket->_Set(
            Field   => 'TimeWorked',
            Value   => $parent_ticket->TimeWorked + $time_worked,
        );
        unless ($ret) {
            RT->Logger->error(
                "Failed to update parent ticket's TimeWorked: $msg");
        }
    }
}

1;
