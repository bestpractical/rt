package RT::Ticket;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "each_req";
  $self->{'user'} = shift;
  return $self;
}


sub create {
  my $self = shift;
#  print STDERR "RT::Article::create::",join(", ",@_),"\n";
  my $id = $self->SUPER::create(@_);
  $self->load_by_reference($id);

  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data

#sub create is handled by the baseclass. we should be calling it like this:
#$id = $article->create( title => "This is a a title",
#		  mimetype => "text/plain",
#		  author => "jesse@arepa.com",
#		  summary => "this article explains how to from a widget",
#		  content => "lots and lots of content goes here. it doesn't 
#                              need to be preqoted");
# TODO: created is not autoset
}
sub created {
  my $self = shift;
  $self->_set_and_return('created',@_);
}


sub SerialNum {
  my $self = shift;
  return($self->id);
}
sub EffectiveSm {
  my $self = shift;
  $self->_set_and_return('effective_sn',@_);
}
sub Queue {
  my $self = shift;
  return ($self->queue_id);
}
sub QueueId {
  my $self = shift;
  my ($new_queue, $queue_obj);
  
  #TODO: does this work?
  if ($new_queue = shift) {
    $queue_obj = RT::Queue->new($self->CurrentUser);
    if (!$queue_obj->load($new_queue);) {
      return (0, "That queue does not exist");
   }
    if (!$queue_obj->Create_Permitted) {
      return (0, "You may not create requests in that queue");
      }
  }
  $self->_set_and_return('queue_id',@_);
}


sub Area {
  my $self = shift;
  

  #TODO: if we get an area check to see if it's a valid area in this queue

  $self->_set_and_return('area',@_);
}
sub Alias {
  my $self = shift;
  #TODO
  $self->_set_and_return('alias',@_);
}

sub Requestors{
  my $self = shift;
  $self->_set_and_return('requestors',@_);
}

sub Take {
  my $self=shift;
  $self->Owner($self->CurrentUser);
}
sub Unake {
  my $self=shift;
  $self->Owner("");
}


sub Owner {
  my $self = shift;
  if ($new_owner = shift) {
    #new owner can be blank or the name of a new owner.
    if (($new_owner != '') and (!$self->Modify_Permitted($new_owner))) {
      return (0, "That user may not own requests in that queue")
    }
  }
  
  if (($new_owner != $self->Owner()) and ($self->Owner != '')) {
    return("You can only reassign tickets that you own or that are unowned");
  }
  $self->_set_and_return('owner',$new_owner);
}


sub Steal {
  my $self = shift;
  
  if (!$self->CanManipulate($self->CurrentUser)){
    return ("Permission Denied");
  }
  elsif ($self->Owner == $self->CurrentUser ) {
    return ("You already own this ticket"); 
  }
  
  else {
    # TODO: Send a "This ticket was stolen from you" alert
    return($self->_set_and_return('owner',$self->CurrentUser));
  }
  
}

sub Subject {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}

sub InitialPriority {
  my $self = shift;
  #we never allow this to be reset
  $self->_set_and_return('initial_priority');
}

sub FinalPriority {
  my $self = shift;
  $self->_set_and_return('final_priority',@_);
}

sub Priority {
  my $self = shift;
  $self->_set_and_return('priority',@_);
}

sub Status { 
  my $self = shift;
  my $status = shift || my $status = undef;
  if (($status) and ($status != 'open') and ($status != 'stalled') and 
      ($status != 'resolved') and ($status != 'dead') ) {
    return ("That status is not valid.");
  }
  
  if ($status == 'resolved') {

    #&open_parents($in_serial_num, $in_current_user) || $transaction_num=0; 
    #TODO: we need to check for open parents.
  }
  
  $self->_set_and_return('status',@_);
}

sub Kill {
  my $self = shift;
  die "Ticket::Kill Unimplemented";
}

sub Stall {
  my $self = shift;
  return ($Self->Status('stalled'));
  
}

sub Open {
  my $self = shift;
  return ($Self->Status('open'));
}

sub Resolve {
  my $self = shift;
  return ($Self->Status('resolved'));
}

sub TimeWorked {
  my $self = shift;
  $self->_set_and_return('time_worked',@_);
}

sub DateCreated {
  my $self = shift;
  $self->_set_and_return('date_created');
}

sub Notify {
  my $self = shift;
  return ($self->DateTold(@_));
}

sub DateTold {
  my $self = shift;
  $self->_set_and_return('date_told',@_);
}

sub DateDue {
  my $self = shift;
  $self->_set_and_return('date_due',@_);
}



#takes a subject, a cc list, a bcc list

sub NewComment {
  my $self = shift;
  #TODO implement
}

sub NewCorrespondence {
  my $self;
  my $content = shift;
  my $subject = shift;
  my $sender = shift;
  my $cc = shift;
  my $bcc = shift;

  my $status = shift;
  

  #Record the correspondence (write the transaction)
  
  #Send a copy to the queue members, if necessary
  
  #Send a copy to the owner if necesary

  if (!$self->IsRequestor($sender)) {
    #Send a copy of the correspondence to the user
    #Flip the date_told to now

  }
  elsif ($cc || $bcc ) {
    #send a copy of the correspondence to the CC list and BCC list
  }
  

  #If there's a status change, call $self->Status($status);
  
  #If we've sent the correspondence to the user, flip the note the date_told
  

  return ("This correspondence has been recorded");
}



sub _NewTransaction {
  my $self = shift;
  my $time_taken = shift;
  my $type = shift;
  my $data = shift;
  my $content = shift;
  my $trans = new RT::Transaction($self->CurrentUser);
  $trans->Create( effective_sn => $self->EffectiveSN,
		  ticket => $self->Id, 		  
		  time_taken => "$time_taken",
		  actor => $self->CurrentUser,
		  type => "$type",
		  data => "$data",
		  date => time,
		  content => "$content"
		);
  
  
}

sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    $self->{'transactions'} = new RT::Transactions($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'effective_sn',
                                    VALUE => $self->id() );
  }
  return($self->{'transactions'});
}




#KEYWORDS IS NOT YET IMPLEMENTEd
sub Keywords {
  my $self = shift;
  if (!$self->{'article_keys'}) {
    $self->{'article_keys'} = new RT::Article::Keywords;
    $self->{'article_keys'}->Limit( FIELD => 'article',
				    VALUE => $self->id() );
  }
  return($self->{'article_keys'});
}

sub NewKeyword {
  my $self = shift;
  my $keyid = shift;
  
    my ($keyword);
  
  $keyword = new RT::Article::Keyword;
  return($keyword->create( keyword => "$keyid",
			   article => $self->id));
  
  #reset the keyword listing...
  $self->{'article_keys'} = undef;
  
  return();
  
}


#LINKS IS NOT YET IMPLEMENTED
sub Links {
  my $self= shift;
  
  if (! $self->{'pointer_to_links_object'}) {
    $self->{'pointer_to_links_object'} = new RT::Article::URLs;
    $self->{'pointer_to_links_object'}->Limit(FIELD => 'article',
					      VALUE => $self->id);
  }
  
  return($self->{'pointer_to_links_object'});
}

sub NewLink {
  my $self = shift;
  my %args = ( url => '',
	       title => '',
	       comment => '',
	       @_
	     );

 
  print STDERR "in article->newlink\n";
  
  my $link = new RT::Article::URL;
  print STDERR "made new link\n";
  
  $id = $link->create( url => $args{'url'},
		       title => $args{'title'},
		       comment => $args{'comment'},
		       article => $self->id()
		     );
    print STDERR "made new create\n";
 return ($id);
}

 

#
# UTILITY METHODS
# 
    
sub CurrentUser {
  my $self = shift;
  return($self->{'user'});
}

sub IsRequestor {
  my $self = shift;
  my $username = shift;
  
  #
  # TODO: we need to actually do a compoarieson here. 
  #
  # if the user is a requestor:
  return(1);
  #else
  return(undef);
  #
};


#
# PRIVATE UTILITY METHODS
#



sub _update_date_acted {
  my $self = shift;
  $self->SUPER::_set_and_return('date_acted',time);
}
sub _set_and_return {
  my $self = shift;
  my $field = shift;
  #if the user is trying to display only {
  if (@_ == undef) {
    
    if ($self->Display_Permitted) {
      #if the user doesn't have display permission, return an error
      $self->SUPER::_set_and_return($field);
    }
    else {
      return(0, "Permission Denied");
    }
  }
  #if the user is trying to modify the record
  else {
    if ($self->Modify_Permitted) {
      #instantiate a transaction 
 
     #record what's being done in the transaction
 
      #Figure out where to send mail
      
      $self->_update_date_acted;

      $self->SUPER::_set_and_return($field, @_);
    }
    else {
      return (0, "Permission Denied");
    }
  }
  
}

#
#ACCESS CONTROL
# 
sub Display_Permitted {
  my $self = shift;
  my $actor = shift || my $actor = $self->CurrentUser;
  return(1);
  #if it's not permitted,
  return(0);

}
sub Modify_Permitted {
  my $self = shift;
 my $actor = shift || my $actor = $self->CurrentUser;
  return(1);
  #if it's not permitted,
  return(0);

}

1;


