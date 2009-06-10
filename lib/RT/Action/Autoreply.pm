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
package RT::Action::Autoreply;
require RT::Action::SendEmail;

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
	if ($RT::UseFriendlyFromLine) {
	    my $friendly_name = $self->TicketObj->QueueObj->Description ||
		    $self->TicketObj->QueueObj->Name;
	    $friendly_name =~ s/"/\\"/g;
	    $self->SetHeader( 'From',
		        sprintf($RT::FriendlyFromLineFormat, 
                $self->MIMEEncodeString( $friendly_name, $RT::EmailOutputEncoding ), $replyto),
	    );
	}
	else {
	    $self->SetHeader( 'From', $replyto );
	}
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
