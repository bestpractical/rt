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


sub serial_num {
  my $self = shift;
  return($self->id);
}
sub effective_sn {
  my $self = shift;
  $self->_set_and_return('effective_sn',@_);
}
sub queue {
my $self = shift;
return ($self->queue_id);
}
sub queue_id {
  my $self = shift;
  my ($new_queue, $queue_obj);
  
  #TODO: does this work?
  if ($new_queue = shift) {
    $queue_obj = RT::Queue->new($self->{'user'});
    if (!$queue_obj->load($new_queue);) {
      return (0, "That queue does not exist");
   }
    if (!$queue_obj->Create_Permitted) {
      return (0, "You may not create requests in that queue");
      }
  }
  $self->_set_and_return('queue_id',@_);
}


sub area {
  my $self = shift;
  $self->_set_and_return('area',@_);
}
sub alias {
  my $self = shift;
  $self->_set_and_return('alias',@_);
}

sub requestors{
  my $self = shift;
  $self->_set_and_return('requestors',@_);
}
sub owner{
  my $self = shift;
  if ($new_owner = shift) {
    if (!$self->Modify_Permitted($new_owner)) {
      return (0, "That user may not own requests in that queue")
    }
  }
  $self->_set_and_return('owner',@_);
}
sub subject {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}
sub initial_priority {
  my $self = shift;
  $self->_set_and_return('initial_priority',@_);
}
sub final_priority {
  my $self = shift;
  $self->_set_and_return('final_priority',@_);
}
sub priority {
  my $self = shift;
  $self->_set_and_return('priority',@_);
}
sub status { 
  my $self = shift;
  $self->_set_and_return('status',@_);
}
sub time_worked {
  my $self = shift;
  $self->_set_and_return('time_worked',@_);
}
sub date_created {
  my $self = shift;
  $self->_set_and_return('date_created');
}
sub date_told {
  my $self = shift;
  $self->_set_and_return('date_told',@_);
}

sub date_due {
  my $self = shift;
  $self->_set_and_return('date_due',@_);
}


#takes a subject, a cc list, a bcc list

sub new_comment {
  my $self = shift;
  #TODO implement
}

sub new_correspondence {
  my $self;
  #TODO implement
}


sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    $self->{'transactions'} = new RT::Transactions($self->{'user'};
    $self->{'transactions'}->Limit( FIELD => 'serial_num',
                                    VALUE => $self->id() );
  }
  return($self->{'article_keys'});
}




#KEYWORDS IS NOT YET IMPLEMENTEd
sub keywords {
  my $self = shift;
  if (!$self->{'article_keys'}) {
    $self->{'article_keys'} = new RT::Article::Keywords;
    $self->{'article_keys'}->Limit( FIELD => 'article',
				    VALUE => $self->id() );
  }
  return($self->{'article_keys'});
}

sub new_keyword {
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
sub links {
  my $self= shift;
  
  if (! $self->{'pointer_to_links_object'}) {
    $self->{'pointer_to_links_object'} = new RT::Article::URLs;
    $self->{'pointer_to_links_object'}->Limit(FIELD => 'article',
					      VALUE => $self->id);
  }
  
  return($self->{'pointer_to_links_object'});
}

sub new_link {
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
  
    
  
sub Display_Permitted {
  my $self = shift;
  my $actor = shift || my $actor = $self->{'user'};
  return(1);
  #if it's not permitted,
  return(0);

}
sub Modify_Permitted {
  my $self = shift;
 my $actor = shift || my $actor = $self->{'user'};
  return(1);
  #if it's not permitted,
  return(0);

}

1;


