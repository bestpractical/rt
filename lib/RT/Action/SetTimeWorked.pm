# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::Action::SetTimeWorked;

use strict;
use warnings;
use base qw(RT::Action);

use Scalar::Util qw(looks_like_number);

=head1 DESCRIPTION

Provide a time argument in minutes for how much time to add to
the current tickets time worked value. This action will only
run when Privileged users comment or reply.

=cut

sub Prepare {
    my $self = shift;

    # Only set time worked for privileged users
    return 0 unless $self->TransactionObj->CreatorObj->Privileged;

    # If we are batch stage we will check to see if any time worked values have already been set
    if ( $self->ScripObj->Stage( TicketObj => $self->TicketObj ) eq 'TransactionBatch' ) {
        foreach my $transaction ( @{$self->TicketObj->TransactionBatch} ) {
            next unless $self->TransactionObj->TimeTaken;
            return;
        }
    }
    # Skip this action if TimeTaken is being updated
    return if $self->TransactionObj->TimeTaken;

    return 1;
}

sub Commit {
    my $self = shift;
    my $time = $self->Argument;
    unless ( $time ) {
        RT::Logger->error( "Time argument required for RT::Action::SetTimeWorked, none was provided" );
        return;
    }
    unless ( looks_like_number( $time ) ) {
        RT::Logger->error( "Time argument for RT::Action::SetTimeWorked must be a number: $time is invalid" );
        return;
    }

    my $timeWorked = $self->TicketObj->TimeWorked || 0;

    # Add 15 minutes to time worked
    my $newValue = $timeWorked + $time;

    # Load a ticket in the context of the user sending the message
    my $ticketObj = RT::Ticket->new( $self->TransactionObj->CreatorObj );
    my ($ret, $msg) = $ticketObj->Load( $self->TicketObj->Id );
    unless ( $ret ) {
        RT::Logger->error( "Could not load ticket #".$self->TicketObj->Id." in user context: $msg" );
        return;
    }

    ($ret, $msg) = $ticketObj->SetTimeWorked( $newValue );
    RT::Logger->error ( "Could not update time worked: $msg" ) unless $ret;
    return $ret;
}

RT::Base->_ImportOverlays();

1;
