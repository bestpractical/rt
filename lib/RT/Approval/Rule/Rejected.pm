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

package RT::Approval::Rule::Rejected;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "If an approval is rejected, reject the original and delete pending approvals"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    return (0)
        unless $self->OnStatusChange('rejected') or $self->OnStatusChange('deleted')
}

sub Commit {    # XXX: from custom prepare code
    my $self = shift;
    if ( my ($rejected) =
        $self->TicketObj->AllDependedOnBy( Type => 'ticket' ) ) {
        my $note = $self->GetNotes;

        my $template = $self->GetTemplate('Approval Rejected',
                                          TicketObj => $rejected,
                                          Approval  => $self->TicketObj,
                                          Approver  => $self->TransactionObj->CreatorObj,
                                          Notes     => $note);

        $rejected->Correspond( MIMEObj => $template->MIMEObj );
        $rejected->SetStatus(
            Status => $rejected->LifecycleObj->DefaultStatus('denied') || 'rejected',
            Force  => 1,
        );
    }
    my $links = $self->TicketObj->DependedOnBy;
    foreach my $link ( @{ $links->ItemsArrayRef } ) {
        my $obj = $link->BaseObj;
        if ( $obj->QueueObj->IsActiveStatus( $obj->Status ) ) {
            if ( $obj->Type eq 'approval' ) {
                $obj->SetStatus(
                    Status => 'deleted',
                    Force  => 1,
                );
            }
        }
    }

    $links = $self->TicketObj->DependsOn;
    foreach my $link ( @{ $links->ItemsArrayRef } ) {
        my $obj = $link->TargetObj;
        if ( $obj->QueueObj->IsActiveStatus( $obj->Status ) ) {
            $obj->SetStatus(
                Status => 'deleted',
                Force  => 1,
            );
        }
    }

}

sub GetNotes {
    my $self = shift;
    my $note = '';

    if ( RT->Config->Get('ApprovalRejectionNotes') ) {
        my $t = $self->TicketObj->Transactions;
        while ( my $o = $t->Next ) {
            next unless $o->Type eq 'Correspond';
            $note .= $o->Content . "\n" if $o->ContentObj;
        }
    }
    return $note;
}

RT::Base->_ImportOverlays();

1;
