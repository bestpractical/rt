# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::Action::Notify;
require RT::Action::SendEmail;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::SendEmail);

# {{{ sub SetRecipients

=head2 SetRecipients

Sets the recipients of this meesage to Owner, Requestor, AdminCc, Cc or All. 
Explicitly B<does not> notify the creator of the transaction by default

=cut

sub SetRecipients {
    my $self = shift;

    my $arg = $self->Argument;

    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;

    my ( @To, @PseudoTo, @Cc, @Bcc );


    if ($arg =~ /\bOtherRecipients\b/) {
        if ($self->TransactionObj->Attachments->First) {
            push (@Cc, $self->TransactionObj->Attachments->First->GetHeader('RT-Send-Cc'));
            push (@Bcc, $self->TransactionObj->Attachments->First->GetHeader('RT-Send-Bcc'));
        }
    }

    if ( $arg =~ /\bRequestor\b/ ) {
        push ( @To, $self->TicketObj->Requestors->MemberEmailAddresses  );
    }

    

    if ( $arg =~ /\bCc\b/ ) {

        #If we have a To, make the Ccs, Ccs, otherwise, promote them to To
        if (@To) {
            push ( @Cc, $self->TicketObj->Cc->MemberEmailAddresses );
            push ( @Cc, $self->TicketObj->QueueObj->Cc->MemberEmailAddresses  );
        }
        else {
            push ( @Cc, $self->TicketObj->Cc->MemberEmailAddresses  );
            push ( @To, $self->TicketObj->QueueObj->Cc->MemberEmailAddresses  );
        }
    }

    if ( ( $arg =~ /\bOwner\b/ )
        && ( $self->TicketObj->OwnerObj->id != $RT::Nobody->id ) )
    {

        # If we're not sending to Ccs or requestors, 
        # then the Owner can be the To.
        if (@To) {
            push ( @Bcc, $self->TicketObj->OwnerObj->EmailAddress );
        }
        else {
            push ( @To, $self->TicketObj->OwnerObj->EmailAddress );
        }

    }

    if ( $arg =~ /\bAdminCc\b/ ) {
        push ( @Bcc, $self->TicketObj->AdminCc->MemberEmailAddresses  );
        push ( @Bcc, $self->TicketObj->QueueObj->AdminCc->MemberEmailAddresses  );
    }

    if ($RT::UseFriendlyToLine) {
        unless (@To) {
            push (
		@PseudoTo,
		sprintf($RT::FriendlyToLineFormat, $arg, $self->TicketObj->id),
	    );
        }
    }

    my $creator = $self->TransactionObj->CreatorObj->EmailAddress();

    #Strip the sender out of the To, Cc and AdminCc and set the 
    # recipients fields used to build the message by the superclass.
    # unless a flag is set 
    if ($RT::NotifyActor) {
        @{ $self->{'To'} }  = @To;
        @{ $self->{'Cc'} }  = @Cc;
        @{ $self->{'Bcc'} } = @Bcc;
    }
    else {
        @{ $self->{'To'} }  = grep ( !/^$creator$/, @To );
        @{ $self->{'Cc'} }  = grep ( !/^$creator$/, @Cc );
        @{ $self->{'Bcc'} } = grep ( !/^$creator$/, @Bcc );
    }
    @{ $self->{'PseudoTo'} } = @PseudoTo;
    return (1);

}

# }}}

eval "require RT::Action::Notify_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Notify_Vendor.pm});
eval "require RT::Action::Notify_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Notify_Local.pm});

1;
