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
package RT::Action::Autoreply;
require RT::Action::SendEmail;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::SendEmail);


# {{{ sub SetRecipients

=head2 SetRecipients

Sets the recipients of this message to this ticket's Requestor.

=cut


sub SetRecipients {
    my $self=shift;

    push(@{$self->{'To'}}, $self->TicketObj->Requestors->MemberEmailAddresses);
    
    return(1);
}

# }}}


# {{{ sub SetReturnAddress 

=head2 SetReturnAddress

Set this message\'s return address to the apropriate queue address

=cut

sub SetReturnAddress {
    my $self = shift;
    my %args = ( is_comment => 0,
		 @_
	       );
    
    my $replyto;
    if ($args{'is_comment'}) { 
	$replyto = $self->TicketObj->QueueObj->CommentAddress || 
		     $RT::CommentAddress;
    }
    else {
	$replyto = $self->TicketObj->QueueObj->CorrespondAddress ||
		     $RT::CorrespondAddress;
    }
    
    unless ($self->TemplateObj->MIMEObj->head->get('From')) {
	my $friendly_name = $self->TicketObj->QueueObj->Description ||
		$self->TicketObj->QueueObj->Name;
	$friendly_name =~ s/"/\\"/g;
	$self->SetHeader('From', "\"$friendly_name\" <$replyto>");
    }
    
    unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
	$self->SetHeader('Reply-To', "$replyto");
    }
    
}
  
# }}}

eval "require RT::Action::Autoreply_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Autoreply_Vendor.pm});
eval "require RT::Action::Autoreply_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Autoreply_Local.pm});

1;
