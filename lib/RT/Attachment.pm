# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
#
package RT::Attachment;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  
  $self->{'table'} = "Attachments";
  $self->_Init(@_);
  return ($self);
}
# }}}



# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      TransactionId => 'read',
	      MessageId => 'read',
	      ContentType => 'read',
	      Subject => 'read',
	      Content => 'read',
	      Headers => 'read',
	      Filename => 'read',
	      Creator => 'read',
	      Created => 'read'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

sub TransactionObj {
    require RT::Transaction;
    my $self=shift;
    unless (exists $self->{_TransactionObj}) {
	$self->{_TransactionObj}=RT::Transaction->new($self->Creator);
	$self->{_TransactionObj}->Load($self->TransactionId);
    }
    return $self->{_TransactionObj};
}

#take simple args and call RT::Record to do the real work.
# {{{ sub Create 

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
			       Created => undef,
	
			      );
    
  for (my $Counter = 0; $Counter < $Attachment->parts(); $Counter++) {
      my $SubAttachment = new RT::Attachment($self->CurrentUser);
      $SubAttachment->Create(TransactionId => $args{'TransactionId'},
			     Parent => "$id",
			     Attachment => $Attachment->part($Counter),
			     ContentType  => $Attachment->mime_type,
			     Headers => $Attachment->head->as_string(),
		
			    );
    }
    return ($id);
  }
  
  
  #If it's not multipart
  else {
    
    
    #can't call a method on an undefined object
    
    my $Body = $Attachment->bodyhandle->as_string;
      

    my $id = $self->SUPER::Create(TransactionId => $args{'TransactionId'},
				  ContentType  => $Attachment->mime_type,
				  Parent => $args{'Parent'},
				  Content => $Body,
				  Headers => $Attachment->head->as_string,
				  Subject => $Subject,
				  Filename => $Filename,
				  Created => undef,
				 );
    return ($id);
  }
}

# }}}


# {{{ sub Quote - it might be possible to use the Mail::Internet
# utility methods ... but I do have a slight feeling that we'd rather
# want to keep the old stuff I've made for rt1 ... or what? :)

sub Quote {
    my $self=shift;
    my %args=(Reply=>undef, # Prefilled reply (i.e. from the KB/FAQ system)
	      @_);
    my ($quoted_content, $body, $headers);
    my $max=0;
    if ($self->ContentType =~ m{^(text/plain|message)}) {
	$body=$self->Content;

	# Do we need any preformatting (wrapping, that is) of the message?

	# Remove trailing headers (from 1.0, this one might probably
	# be gutted)
	$body =~ s/--- Headers Follow ---\n\n(.*)$//s;

	# Remove quoted signature.
	$body =~ s/\n-- (.*)$//s;

	# What's the longest line like?
	foreach (split (/\n/,$body)) {
	    $max=length if length>$max;
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

	$body = '[' . $self->TransactionObj->Creator->UserId . ' - ' . $self->TransactionObj->AgeAsString 
	            . "]\n\n[REMOVE THIS LINE, AND ANY EXCESSIVE LINES BELOW]\n"
   	        . $body . "\n\n";

    } else {
	$body = "[non-text message gutted]\n\n";
    }
    
    $body .= "[REMOVE THIS LINE. DOES THE REPLY MATCH THE QUESTION?]\n$args{Reply}"
	if (defined($args{Reply}));
    
    $max=60 if $max<60;
    $max=70 if $max>78;
    $max+=2;
    return (\$body, $max);
}
# }}}



#ACCESS CONTROL
# 
# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }
  if (1) {
#  if ($self->Queue->DisplayPermitted($actor)) {
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}

# {{{ sub ModifyPermitted 
sub ModifyPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }
  if ($self->Queue->ModifyPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}

# {{{ sub AdminPermitted 
sub AdminPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }


  if ($self->Queue->AdminPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}
1;
