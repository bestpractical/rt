# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

=head1 NAME

  RT::Attachment -- an RT attachment object

=head1 SYNOPSIS

  use RT::Attachment;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=head1 METHODS

=cut

package RT::Attachment;
use RT::Record;
use MIME::Base64;
use vars qw|@ISA|;
@ISA= qw(RT::Record);

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

#take simple args and call RT::Record to do the real work.

# {{{ sub Create 

=head2 Create

Create a new attachment. Takes a paramhash:
    
    'Attachment' Should be a single MIME body with optional subparts
    'Parent' is an optional Parent RT::Attachment object
    'TransactionId' is the mandatory id of the Transaction this attachment is associated with.;

=cut

sub Create  {
    my $self = shift;
    my ($id);
    my %args = ( id => 0,
		 TransactionId => 0,
		 Parent => 0,
		 Attachment => undef,
		 @_
	       );
    
    
    #For ease of reference
    my $Attachment = $args{'Attachment'};
    
    #if we didn't specify a ticket, we need to bail
    if ( $args{'TransactionId'} == 0) {
	die "RT::Attachment->Create couldn't, as you didn't specify a transaction\n";
    }
    
    #If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;
    
    #Get the subject
    my $Subject = $Attachment->head->get('subject',0);
    defined($Subject) or $Subject = '';
    chomp($Subject);
  
    #Get the filename
    my $Filename = $Attachment->head->recommended_filename;
    
    if ($Attachment->is_multipart) {
	$id = $self->SUPER::Create(TransactionId => $args{'TransactionId'},
				   Parent => 0,
				   ContentType  => $Attachment->mime_type,
				   Headers => $Attachment->head->as_string,
				   Subject => $Subject,
				   
				  );
	
	for (my $Counter = 0; $Counter < $Attachment->parts(); $Counter++) {
	    my $SubAttachment = new RT::Attachment($self->CurrentUser);
	    $SubAttachment->Create(TransactionId => $args{'TransactionId'},
				   Parent => "$id",
				   
				   # This was "part", and has always worked
				   # until I upgraded MIME::Entity.  seems
				   # like "parts" should work according to
				   # the doc?
				   
				   Attachment => $Attachment->parts($Counter),
				   ContentType  => $Attachment->mime_type,
				   Headers => $Attachment->head->as_string(),
				   
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
	
	if ( (! $RT::Handle->BinarySafeBLOBs) &&
	     ( $Body =~ /\x00/ ) ) {
	    # set a flag telling us to mimencode the attachment
	    $ContentEncoding = 'base64';
	    
	    #cut the max attchment size by 25% (for mime-encoding overhead.
	    $MaxSize = $MaxSize * 3/4;	
	}
	
	#if the attachment is larger than the maximum size
	if (($MaxSize) and ($MaxSize < length($body))) {
	    # if we're supposed to truncate large attachments
	    if ($RT::TruncateLongAttachments) {
		# truncate the attachment to that length.
	    }
	    
	    # elsif we're supposed to drop large attachments on the floor,
	    elsif ($RT::DropLongAttachments) {
		# drop the attachment on the floor
		return(undef);
		# TODO percolate an error up	
		
	    }
	}
	# if we need to mimencode the attachment
	if ($ContentEncoding eq 'base64') {
	    # base64 encode the attachment
	    $Body = base64_encode($Body);
	    
	}
	
	my $id = $self->SUPER::Create(TransactionId => $args{'TransactionId'},
				      ContentType  => $Attachment->mime_type,
				      ContentEncoding => $ContentEncoding,
				      Parent => $args{'Parent'},
				      Content => $Body,
				      Headers => $Attachment->head->as_string,
				      Subject => $Subject,
				      Filename => $Filename,
				     );
	return ($id);
    }
}

# }}}


# {{{ sub Content

=head2 Content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub Content {
  my $self = shift;
  if ( $self->ContentEncoding eq 'none' || ! $self->ContentEncoding ) {
      return $self->_Value('Content');
  } elsif ( $self->ContentEncoding eq 'base64' ) {
      return decode_base64($self->_Value('Content'));
  } else {
      return( "Unknown ContentEncoding ". $self->ContentEncoding);
  }
}


# }}}

# {{{ UTILITIES

# {{{ sub Quote 

# - it might be possible to use the Mail::Internet
# utility methods ... but I do have a slight feeling that we'd rather
# want to keep the old stuff I've made for rt1 ... or what? :)

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

    #Attache the user's signature if we have it. 
    $body .= "\n\n-- \n" . $self->CurrentUser->UserObj->Signature
	if ($self->CurrentUser->UserObj->Signature);
    return (\$body, $max);
}
# }}}

# {{{ sub NiceHeaders - pulls out only the most relevant headers
sub NiceHeaders {
    my $self=shift;
    my $hdrs="";
    for (split(/\n/,$self->Headers)) {
	$hdrs.="$_\n"
	    if /^(To|From|Cc|Date|Subject): /i
    }
    return $hdrs;
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
	return($self->__Value($field));
	
    }
    
    #If it's a comment, we need to be extra special careful
    elsif ( (($self->TransactionObj->CurrentUserHasRight('ShowTicketComments')) and
	     ($self->TransactionObj->Type eq 'Comment') )  or
	    ($self->TransactionObj->CurrentUserHasRight('ShowTicket'))) {
	
	return($self->__Value($field));
    }
    #if they ain't got rights to see, don't let em
    else {
	    return(undef);
	}
    	
    
}

# }}}

# }}}

1;
