# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

package RT::Action::UpdateUserTimeWorked;
use base 'RT::Action';

=head1 NAME

RT::Action::UpdateUserTimeWorked - RT's scrip action to set/update the time
worked for a user each time they log time worked on a ticket

=head1 DESCRIPTION

This action is used as an action for the 'On TimeWorked Change' condition.

When it fires, a ticket attribute stores the amount of time the user updating
the ticket worked on it.

=cut

sub Prepare {
    return 1;
}

sub Commit {
    my $self   = shift;
    my $ticket = $self->TicketObj;
    my $txn    = $self->TransactionObj;

    my $time_worked_attr = $ticket->FirstAttribute('TimeWorked');
    # if the attribute is not defined, we will initialize it in the callback,
    # so no need to handle it here
    if ( $time_worked_attr ) {
        my $time_worked = $time_worked_attr->Content;
        $time_worked->{ $txn->CreatorObj->Name } += $txn->TimeTaken
          || $txn->NewValue - $txn->OldValue;
        $time_worked_attr->SetContent( $time_worked );
    }
}

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=cut

1;
