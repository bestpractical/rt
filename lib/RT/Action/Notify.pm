# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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
require RT::Action::SendEmail;
use Mail::Address;
use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::SendEmail);


=head2 Prepare

Set up the relevant recipients, then call our parent.

=cut


sub Prepare {
    my $self = shift;
    $self->SetRecipients();
    $self->SUPER::Prepare();
}

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


    if ( $arg =~ /\bOtherRecipients\b/ ) {
        if ( $self->TransactionObj->Attachments->First ) {
            my @cc_addresses = Mail::Address->parse($self->TransactionObj->Attachments->First->GetHeader('RT-Send-Cc'));
            foreach my $addr (@cc_addresses) {
                  push @Cc, $addr->address;
            }
            my @bcc_addresses = Mail::Address->parse($self->TransactionObj->Attachments->First->GetHeader('RT-Send-Bcc'));

            foreach my $addr (@bcc_addresses) {
                  push @Bcc, $addr->address;
            }

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
        @{ $self->{'To'} }  = grep ( lc $_ ne lc $creator, @To );
        @{ $self->{'Cc'} }  = grep ( lc $_ ne lc $creator, @Cc );
        @{ $self->{'Bcc'} } = grep ( lc $_ ne lc $creator, @Bcc );
    }
    @{ $self->{'PseudoTo'} } = @PseudoTo;


}

# }}}

eval "require RT::Action::Notify_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Notify_Vendor.pm});
eval "require RT::Action::Notify_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Notify_Local.pm});

1;
