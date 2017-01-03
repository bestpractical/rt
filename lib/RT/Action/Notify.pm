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

#
package RT::Action::Notify;

use strict;
use warnings;

use base qw(RT::Action::SendEmail);

use Email::Address;

=head2 Prepare

Set up the relevant recipients, then call our parent.

=cut


sub Prepare {
    my $self = shift;
    $self->SetRecipients();
    $self->SUPER::Prepare();
}

=head2 SetRecipients

Sets the recipients of this message to Owner, Requestor, AdminCc, Cc or All.
Explicitly B<does not> notify the creator of the transaction by default.

=cut

sub SetRecipients {
    my $self = shift;

    my $ticket = $self->TicketObj;

    my $arg = $self->Argument;
    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;

    my ( @To, @PseudoTo, @Cc, @Bcc );


    if ( $arg =~ /\bRequestor\b/ ) {
        push @To, $ticket->Requestors->MemberEmailAddresses;
    }

    if ( $arg =~ /\bCc\b/ ) {

        #If we have a To, make the Ccs, Ccs, otherwise, promote them to To
        if (@To) {
            push ( @Cc, $ticket->Cc->MemberEmailAddresses );
            push ( @Cc, $ticket->QueueObj->Cc->MemberEmailAddresses  );
        }
        else {
            push ( @Cc, $ticket->Cc->MemberEmailAddresses  );
            push ( @To, $ticket->QueueObj->Cc->MemberEmailAddresses  );
        }
    }

    if (   $arg =~ /\bOwner\b/
        && $ticket->OwnerObj->id != RT->Nobody->id
        && $ticket->OwnerObj->EmailAddress
        && not $ticket->OwnerObj->Disabled
    ) {
        # If we're not sending to Ccs or requestors,
        # then the Owner can be the To.
        if (@To) {
            push ( @Bcc, $ticket->OwnerObj->EmailAddress );
        }
        else {
            push ( @To, $ticket->OwnerObj->EmailAddress );
        }

    }

    if ( $arg =~ /\bAdminCc\b/ ) {
        push ( @Bcc, $ticket->AdminCc->MemberEmailAddresses  );
        push ( @Bcc, $ticket->QueueObj->AdminCc->MemberEmailAddresses  );
    }

    if ( RT->Config->Get('UseFriendlyToLine') ) {
        unless (@To) {
            push @PseudoTo,
                sprintf RT->Config->Get('FriendlyToLineFormat'), $arg, $ticket->id;
        }
    }

    @{ $self->{'To'} }       = @To;
    @{ $self->{'Cc'} }       = @Cc;
    @{ $self->{'Bcc'} }      = @Bcc;
    @{ $self->{'PseudoTo'} } = @PseudoTo;

    if ( $arg =~ /\bOtherRecipients\b/ ) {
        if ( my $attachment = $self->TransactionObj->Attachments->First ) {
            push @{ $self->{'NoSquelch'}{'Cc'} ||= [] }, map $_->address,
                Email::Address->parse( $attachment->GetHeader('RT-Send-Cc') );
            push @{ $self->{'NoSquelch'}{'Bcc'} ||= [] }, map $_->address,
                Email::Address->parse( $attachment->GetHeader('RT-Send-Bcc') );
        }
    }
}

=head2 RemoveInappropriateRecipients

Remove transaction creator as appropriate for the NotifyActor setting.

To send email to the selected receipients regardless of RT's NotifyActor
configuration, include AlwaysNotifyActor in the list of arguments.

=cut

sub RemoveInappropriateRecipients {
    my $self = shift;

    my $creatorObj = $self->TransactionObj->CreatorObj;
    my $creator = $creatorObj->EmailAddress() || '';
    my $TransactionCurrentUser = RT::CurrentUser->new;
    $TransactionCurrentUser->LoadByName($creatorObj->Name);

    $self->RecipientFilter(
        Callback => sub {
            return unless lc $_[0] eq lc $creator;
            return "not sending to $creator, creator of the transaction, due to NotifyActor setting";
        },
    ) unless RT->Config->Get('NotifyActor',$TransactionCurrentUser)
             || $self->Argument =~ /\bAlwaysNotifyActor\b/;

    $self->SUPER::RemoveInappropriateRecipients();
}

RT::Base->_ImportOverlays();

1;
