# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::Ticket;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "each_req";
  $self->{'user'} = shift;
  $self->_init(@_);
  return ($self);
}


sub Create {
  my $self = shift;
  return($self->create(@_);)
}

sub create {
  my $self = shift;
 
  my %args = (id => undef,
	      effective_id => undef,
	      queue => undef,
	      area => undef,
	      alias => undef,
	      requestors => undef,
	      owner => undef,
	      subject => undef,
	      initial_priority => undef,
	      final_priority => undef,
	      status => 'open',
	      time_worked => 0,
	      date_created => time(),
	      date_told => 0,
	      date_acted => time(),
	      date_due => 0,
	      content => undef,
	      @_);

  my $id = $self->SUPER::Create(id => $args{'id'},
				effective_id => $args{'effective_id'},
				queue => $args{'queue'},
				area => $args{'area'},
				alias => $args{'alias'},
				requestors => $args{'requestors'},
				owner => $args{'owner'},
				subject => $args{'subject'},
				initial_priority => $args{'initial_priority'},
				final_priority => $args{'final_priority'},
				priority => $args{'initial_priority'},
				status => $args{'status'},
				time_worked => $args{'time_worked'},
				date_created => $args{'date_created'},
				date_told => $args{'date_told'},
				date_acted => $args{'date_acted'},
				date_due => $args{'date_due'}
			       );

  #TODO: ADD A TRANSACTION
  #TODO: DO SOMETHING WITH $args{'content'}

  return($id);

}
sub created {
  my $self = shift;
  $self->_set_and_return('created');
}



sub TicketId {
  my $self = shift;
  return($self->id);
}
sub EffectiveTicket {
  my $self = shift;

  $self->_set_and_return('effective_ticket',@_);
}

sub Queue {
  my $self = shift;
  my ($new_queue, $queue_obj);
  
  #TODO: does this work?
  if ($NewQueue = shift) {
    #TODO this will clobber the old queue definition. 
    #it should load its own queue object, maybe.

    my $NewQueueObj = RT::Queue->new($self->CurrentUser);
    
    if (!$NewQueueObj->load($new_queue)) {
      return (0, "That queue does not exist");
    }
    elsif (!$NewQueueObj->Create_Permitted) {
      return (0, "You may not create requests in that queue.");
    }
    elsif (!$NewQueueObj->ModifyPermitted($self->Owner)) {
      $self->Untake();
    }
    
    #TODO: IF THE AREA DOESN'T EXIST IN THE NEW QUEUE, YANK IT.
    
    else {
      $self->_set_and_return('queue',$new_queue);
    }
  }
  #if they're not setting the queueid, just return a queue object
  else {
    
    if (!$self->{'queue'})  {
      require RT::Queue;
      $self->{'queue'} = RT::Queue->new($self->CurrentUser);
      $self->{'queue'}->load($self->_set_and_return('queue'));
    }
    return ($self->{'queue'});
    
}

    return($self->{'queue'});
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

sub Untake {
  my $self=shift;
  $self->Owner("");
}


sub Owner {
  my $self = shift;
  
  #TODO: does this take the null owner properly?
  if ($new_owner = shift) {
    #new owner can be blank or the name of a new owner.
    if (($new_owner != '') and (!$self->Modify_Permitted($new_owner))) {
      return ("That user may not own requests in that queue")
    }
  }
  elsif ($new_owner eq $self->Owner) {
	return("You already own that request");
	}
  elsif (($self->CurrentUser ne $self->Owner()) and ($self->Owner != '')) {
    return("You can only reassign tickets that you own or that are unowned");
  }
	
#  elsif ( #TODO $new_owner doesn't have queue perms ) {
#	return ("That user doesn't have permission to modify this request");
#	}

  else {
    #TODO
    #If we're giving the request to someone other than $self->CurrentUser
    #send them mail
    $self->_set_and_return('owner',$new_owner);
  }

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
  if (@_) {
   my $status = shift;
 }
  else {
    my $status = undef;
  }
  
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
  return ($self->DateTold(time()));
}
  
sub DateTold {
  my $self = shift;
  $self->_set_and_return('date_told',@_);
}

sub DateDue {
  my $self = shift;
  $self->_set_and_return('date_due',@_);
}

sub SinceTold {
  my $self = shift;
  return ("Ticket->SinceTold unimplemented");
}
sub Age {
  my $self = shift;
  return("Ticket->Age unimplemented\n");
}



#takes a subject, a cc list, a bcc list

sub Comment {
  my $self = shift;
  
  my %args = ( subject => $self->Subject,
	       sender => $self->CurrentUser,
	       cc => undef,
	       bcc => undef,
	       time_taken => 0,
	       content => undef,
	       @_ );
  
  if ($args{'subject'} !~ /\[(\s*)comment(\s*)\]/i) {
    $args{'subject'} .= ' [comment]';
  }
  #Record the correspondence (write the transaction)
  $self->_NewTransaction('comment',$args{'subject'},$args{'time_taken'},
			 $args{'content'});
  
  #Send a copy to the queue members, if necessary
  
  #Send a copy to the owner if necesary
  
  if ($args{'cc'} || $args{'bcc'} ) {
    #send a copy of the correspondence to the CC list and BCC list
  }
  
  return ("This correspondence has been recorded");
}

sub NewCorrespondence {
  my $self = shift;
    my %args = ( subject => $self->Subject,
		 sender => $self->CurrentUser,
		 cc => undef,
		 bcc => undef,
		 time_taken => 0,
		 content => undef,
		 @_ );

  
  #Record the correspondence (write the transaction)
  $self->_NewTransaction('correspondence',$args{'subject'},$args{'time_taken'},$args{'content'});
  
  #Send a copy to the queue members, if necessary
  
  #Send a copy to the owner if necesary
  
  if (!$self->IsRequestor($args{'sender'})) {
    #Send a copy of the correspondence to the user
    #Flip the date_told to now
    #If we've sent the correspondence to the user, flip the note the date_told
  }
  
  elsif ($args{'cc'} || $args{'bcc'} ) {
    #send a copy of the correspondence to the CC list and BCC list
  }
  
  return ("This correspondence has been recorded.");
}



sub _NewTransaction {
  my $self = shift;
  my $type = shift;
  my $data = shift;
  my $time_taken = shift;
  my $content = shift;


  my $trans = new RT::Transaction($self->CurrentUser);
  $trans->Create( Ticket => $self->EffectiveSN,
		  TimeTaken => "$time_taken",
		  Type => "$type",
		  Data => "$data",
		  Content => "$content"
		);
  $self->_UpdateTimeTaken($time_taken); 
}

sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    $self->{'transactions'} = new RT::Transactions($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'effective_ticket',
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
  
  #if the requestors string contains the username

  if ($self->Requestor() =~ /\$username/) {

    return(1);
  }
  else {
    return(undef);
  }
};


#
# PRIVATE UTILITY METHODS
#


sub _UpdateTimeTaken {
  my $self = shift;
  warn("_UpdateTimeTaken not implemented yet.");
  
}

sub _UpdateDateActed {
  my $self = shift;
  $self->SUPER::_set_and_return('date_acted',time);
}
sub _set_and_return {
  my $self = shift;
  my (@args);
  #if the user is trying to display only 
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
  


  if ($self->Modify_Permitted) {
 
    my $field = shift;
    my $value = shift;
    my $time_taken = shift if @_;
    
    #TODO: this doesn't work, iirc.
    
    my $content = @_;
    
    
    #record what's being done in the transaction
    
    $self->_NewTransaction ($field, $value, $time_taken, $content);
    
    $self->_UpdateDateActed;
  
    $self->SUPER::_set_and_return($field, @_);
    
    #Figure out where to send mail
    
    
    
  }
  
  else {
    return (0, "Permission Denied");
  }
}






#
# Actions that don't have a corresponding display component
#

sub Merge {
  my $self = shift;
  my $MergeInto = shift;
  
  #Make sure this user can modify this ticket

  #Load $MergeInto as Ticket $Target
  
  #If the $Target doesn't exist, return an area
  
  
  #Make sure this user can modify $Target
  
  #If I have an owner and the $Target doesn't, set them on the target
  
  #If this ticket has an area and the $Target doesn't, set them on the target
  
  #If I have a Due Date and it's before the $Target's due date, set the $Target's due date
  
  #Give the $Target my requestors
  #    $old_requestors=$req[$in_serial_num]{'requestors'};
#    $new_requestors=$req[$in_merge_into]{'requestors'};
#    @requestors_list=split(/,/ , $old_requestors . ", $new_requestors");
#    foreach $user (@requestors_list) {
#	$user =~ s/\s//g;
#	$user .= "\@$rt::domain" if ! ($user =~ /\@/);
#	$requestors{$user} = 1;
#    }
#    $new_requestors = join(",",sort keys %requestors);
    
  #Set my effective_sn to the $Target's Effective SN.

  #Set all my transactions Effective_SN to the $Target's Effective_Sn
  
  

}  

#
#ACCESS CONTROL
# 
sub DisplayPermitted {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
  if ($self->Queue->DisplayPermitted($actor)) {
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}


sub ModifyPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
  if ($self->Queue->ModifyPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

sub AdminPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }


  if ($self->Queue->AdminPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

1;


