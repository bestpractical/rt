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
=head1 SYNOPSIS

  use RT::Attachment;


=head1 DESCRIPTION

This module should never be instantiated directly by client code. it's an internal 
module which should only be instantiated through exported APIs in Ticket, Queue and other 
similar objects.


=head1 METHODS


=begin testing

ok (require RT::Attachment);

=end testing

=cut

use strict;
no warnings qw(redefine);

use MIME::Base64;

# {{{ sub _Init
sub _Init  {
    my $self = shift; 
    $self->{'table'} = "Attachments";
    return($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _ClassAccessible 
sub _ClassAccessible {
    {
    TransactionId   => { 'read'=>1, 'public'=>1, },
    MessageId       => { 'read'=>1, },
    Parent          => { 'read'=>1, },
    ContentType     => { 'read'=>1, },
    Subject         => { 'read'=>1, },
    Content         => { 'read'=>1, },
    ContentEncoding => { 'read'=>1, },
    Headers         => { 'read'=>1, },
    Filename        => { 'read'=>1, },
    Creator         => { 'read'=>1, 'auto'=>1, },
    Created         => { 'read'=>1, 'auto'=>1, },
  };
}
# }}}

# {{{ sub TransactionObj 

=head2 TransactionObj

Returns the transaction object asscoiated with this attachment.

=cut

sub TransactionObj {
    require RT::Transaction;
    my $self=shift;
    unless (exists $self->{_TransactionObj}) {
	$self->{_TransactionObj}=RT::Transaction->new($self->CurrentUser);
	$self->{_TransactionObj}->Load($self->TransactionId);
    }
    return $self->{_TransactionObj};
}

# }}}

# {{{ sub Create 

=head2 Create

Create a new attachment. Takes a paramhash:
    
    'Attachment' Should be a single MIME body with optional subparts
    'Parent' is an optional Parent RT::Attachment object
    'TransactionId' is the mandatory id of the Transaction this attachment is associated with.;

=cut

sub Create {
    my $self = shift;
    my ($id);
    my %args = ( id            => 0,
                 TransactionId => 0,
                 Parent        => 0,
                 Attachment    => undef,
                 @_ );

    #For ease of reference
    my $Attachment = $args{'Attachment'};

    #if we didn't specify a ticket, we need to bail
    if ( $args{'TransactionId'} == 0 ) {
        $RT::Logger->crit(
"RT::Attachment->Create couldn't, as you didn't specify a transaction\n" );
        return (0);

    }

    #If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;

    #Get the subject
    my $Subject = $Attachment->head->get( 'subject', 0 );
    defined($Subject) or $Subject = '';
    chomp($Subject);

    #Get the filename
    my $Filename = $Attachment->head->recommended_filename;

    if ( $Attachment->parts ) {
        $id = $self->SUPER::Create(
            TransactionId => $args{'TransactionId'},
            Parent        => 0,
            ContentType   => $Attachment->mime_type,
            Headers       => $Attachment->head->as_string,
            Subject       => $Subject,

        );
        foreach my $part ( $Attachment->parts ) {
            my $SubAttachment = new RT::Attachment( $self->CurrentUser );
            $SubAttachment->Create(
                TransactionId => $args{'TransactionId'},
                Parent        => $id,
                Attachment    => $part,
                ContentType   => $Attachment->mime_type,
                Headers       => $Attachment->head->as_string(),

            );
        }
        return ($id);
    }

    #If it's not multipart
    else {

        my $ContentEncoding = 'none';

        my $Body = $Attachment->bodyhandle->as_string;

        #get the max attachment length from RT
        my $MaxSize = $RT::MaxAttachmentSize;

        #if the current attachment contains nulls and the 
        #database doesn't support embedded nulls

        if (    ( !$RT::Handle->BinarySafeBLOBs )
             && ( $Body =~ /\x00/ ) ) {

            # set a flag telling us to mimencode the attachment
            $ContentEncoding = 'base64';

            #cut the max attchment size by 25% (for mime-encoding overhead.
            $RT::Logger->debug("Max size is $MaxSize\n");
            $MaxSize = $MaxSize * 3 / 4;
        }

        #if the attachment is larger than the maximum size
        if ( ($MaxSize) and ( $MaxSize < length($Body) ) ) {

            # if we're supposed to truncate large attachments
            if ($RT::TruncateLongAttachments) {

                # truncate the attachment to that length.
                $Body = substr( $Body, 0, $MaxSize );

            }

            # elsif we're supposed to drop large attachments on the floor,
            elsif ($RT::DropLongAttachments) {

                # drop the attachment on the floor
                $RT::Logger->info( "$self: Dropped an attachment of size "
                                   . length($Body) . "\n"
                                   . "It started: "
                                   . substr( $Body, 0, 60 )
                                   . "\n" );
                return (undef);
            }
        }

        # if we need to mimencode the attachment
        if ( $ContentEncoding eq 'base64' ) {

            # base64 encode the attachment
            $Body = MIME::Base64::encode_base64($Body);

        }

        my $id = $self->SUPER::Create( TransactionId => $args{'TransactionId'},
                                       ContentType   => $Attachment->mime_type,
                                       ContentEncoding => $ContentEncoding,
                                       Parent          => $args{'Parent'},
                                       Content         => $Body,
                                       Headers  => $Attachment->head->as_string,
                                       Subject  => $Subject,
                                       Filename => $Filename, );
        return ($id);
    }
}

# }}}


=head2 Import

Create an attachment exactly as specified in the named parameters.

=cut


sub Import {
    my $self = shift;
    return($self->SUPER::Create(@_));
}

# {{{ sub Content

=head2 Content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub Content {
  my $self = shift;
  if ( $self->ContentEncoding eq 'none' || ! $self->ContentEncoding ) {
      return $self->_Value('Content',
                           decode_utf8 => ($self->ContentType =~ m/^text/i || 0 ) );
  } elsif ( $self->ContentEncoding eq 'base64' ) {
      return MIME::Base64::decode_base64($self->_Value('Content'));
  } else {
      return( $self->loc("Unknown ContentEncoding [_1]", $self->ContentEncoding));
  }
}


# }}}

# {{{ sub Children

=head2 Children

  Returns an RT::Attachments object which is preloaded with all Attachments objects with this Attachment\'s Id as their 'Parent'

=cut

sub Children {
    my $self = shift;
    
    my $kids = new RT::Attachments($self->CurrentUser);
    $kids->ChildrenOf($self->Id);
    return($kids);
}

# }}}

# {{{ UTILITIES

# {{{ sub Quote 



sub Quote {
    my $self=shift;
    my %args=(Reply=>undef, # Prefilled reply (i.e. from the KB/FAQ system)
	      @_);

    my ($quoted_content, $body, $headers);
    my $max=0;

    # TODO: Handle Multipart/Mixed (eventually fix the link in the
    # ShowHistory web template?)
    if ($self->ContentType =~ m{^(text/plain|message)}i) {
	$body=$self->Content;

	# Do we need any preformatting (wrapping, that is) of the message?

	# Remove quoted signature.
	$body =~ s/\n-- \n(.*)$//s;

	# What's the longest line like?
	foreach (split (/\n/,$body)) {
	    $max=length if ( length > $max);
	}

	if ($max>76) {
	    require Text::Wrapper;
	    my $wrapper=new Text::Wrapper
		(
		 columns => 70, 
		 body_start => ($max > 70*3 ? '   ' : ''),
		 par_start => ''
		 );
	    $body=$wrapper->wrap($body);
	}

	$body =~ s/^/> /gm;

	$body = '[' . $self->TransactionObj->CreatorObj->Name() . ' - ' . $self->TransactionObj->CreatedAsString()
	            . "]:\n\n"
   	        . $body . "\n\n";

    } else {
	$body = "[Non-text message not quoted]\n\n";
    }
    
    $max=60 if $max<60;
    $max=70 if $max>78;
    $max+=2;

    return (\$body, $max);
}
# }}}

# {{{ sub NiceHeaders - pulls out only the most relevant headers

=head2 NiceHeaders

Returns the To, From, Cc, Date and Subject headers.

It is a known issue that this breaks if any of these headers are not
properly unfolded.

=cut

sub NiceHeaders {
    my $self=shift;
    my $hdrs="";
    for (split(/\n/,$self->Headers)) {
	    $hdrs.="$_\n" if /^(To|From|RT-Send-Cc|Cc|Date|Subject): /i
    }
    return $hdrs;
}
# }}}

# {{{ sub Headers

=head2 Headers

Returns this object's headers as a string.  This method specifically
removes the RT-Send-Bcc: header, so as to never reveal to whom RT sent a Bcc.
We need to record the RT-Send-Cc and RT-Send-Bcc values so that we can actually send
out mail. (The mailing rules are seperated from the ticket update code by
an abstraction barrier that makes it impossible to pass this data directly

=cut

sub Headers {
    my $self = shift;
    my $hdrs="";
    for (split(/\n/,$self->SUPER::Headers)) {
	    $hdrs.="$_\n" unless /^(RT-Send-Bcc): /i
    }
    return $hdrs;
}


# }}}

# {{{ sub GetHeader

=head2 GetHeader ( 'Tag')

Returns the value of the header Tag as a string. This bypasses the weeding out
done in Headers() above.

=cut

sub GetHeader {
    my $self = shift;
    my $tag = shift;
    foreach my $line (split(/\n/,$self->SUPER::Headers)) {
        if ($line =~ /^$tag:\s+(.*)$/i) { #if we find the header, return its value
            return ($1);
        }
    }
    
    # we found no header. return an empty string
    return undef;
}
# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value  {

    my $self = shift;
    my $field = shift;
    
    
    #if the field is public, return it.
    if ($self->_Accessible($field, 'public')) {
	#$RT::Logger->debug("Skipping ACL check for $field\n");
	return($self->__Value($field, @_));
	
    }
    
    #If it's a comment, we need to be extra special careful
    elsif ( (($self->TransactionObj->CurrentUserHasRight('ShowTicketComments')) and
	     ($self->TransactionObj->Type eq 'Comment') )  or
	    ($self->TransactionObj->CurrentUserHasRight('ShowTicket'))) {
		return($self->__Value($field, @_));
    }
    #if they ain't got rights to see, don't let em
    else {
	    return(undef);
	}
    	
    
}

# }}}

# }}}

1;
