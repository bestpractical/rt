#$Header$

package RT::Queue;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Queues";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = ( QueueId => 'read/write',
	       CorrespondAddress => 'read/write',
	       Description => 'read/write',
	       CommentAddress =>  'read/write',
	       InitialPriority =>  'read/write',
	       FinalPriority =>  'read/write',
	       PermitNonmemberCreate => 'read/write',
	       DefaultDueIn =>  'read/write'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub create 
sub create  {
  my $self = shift;

#  print STDERR "In RT::Queue::create.pm\n";
  my $id = $self->SUPER::Create(QueueId => @_);
#  print STDERR "Loading $id\n";
  $self->LoadById($id);
  
}
# }}}


# {{{ sub delete 
sub delete  {
  my $self = shift;
 # this function needs to move all requests into some other queue!
  my ($query_string,$update_clause);
  
  die ("Queue->Delete not implemented yet");

#If the user is an RT admin      

      #TODO:  DO ALL THESE
      $query_string = "DELETE FROM queues WHERE id = $in_queue_id";
      $query_string = "DELETE FROM queue_acl WHERE queue_id = $in_queue_id";
      $query_string = "DELETE FROM queue_areas WHERE queue_id = $in_queue_id";
      

      return (1, "Queue $in_queue_id deleted.");
 

   }
  else {
    return(0, "You do not have the privileges to delete queue $in_queue_id.");
  }
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  #print "In RT::Queue::Create\n";
  return($self->create(@_));
}
# }}}


# {{{ sub Load 
sub Load  {
  my $self = shift;
  
  my $identifier = shift;
  if (!$identifier) {
    return (undef);
  }	    

  if ($identifier !~ /\D/) {
    return($self->SUPER::LoadById($identifier));
  }
  else {
    
    return($self->LoadByCol("QueueId", $identifier));
  }

}
# }}}

#
# Dealing with Watchers


# {{{ sub AddWatcher

sub AddWatcher {
  my $self = shift;
  my %args = ( Value => $self->Id(),
	       Email => undef,
	       Type => undef,
	       Scope => 'Queue',
	       Owner => 0,
	       @_ );

  #TODO: Look up the Email that's been passed in to find the watcher's
  # user id. Set Owner to that value.
  

  require RT::Watcher;
  my $Watcher = new RT::Watcher ($self->CurrentUser);
  $Watcher->Create(%args);
  
}

# }}}


# {{{ sub AddCc
sub AddCc {
  my $self = shift;
  return ($self->AddWatcher ( Type => 'Cc', @_));
}
# }}}
	
# {{{ sub AddAdminCc

sub AddAdminCc {
  my $self = shift;
  return ($self->AddWatcher ( Type => 'AdminCc', @_));
}
# }}}

# {{{ sub DeleteWatcher

sub DeleteWatcher {
  my $self = shift;
  my $email = shift;
  
  my ($Watcher);
  
  while ($Watcher = $self->Watchers->Next) {
    if ($Watcher->Email =~ /$email/) 
      $Watcher->Delete();
    }
  }
}

# }}}

# {{{ sub AdminCc
sub AdminCc {
  my $self = shift;
  if (! defined ($self->{'AdminCc'}) 
      || $self->{'AdminCc'}->{is_modified}) {
    require RT::Watchers;
    $self->{'AdminCc'} =RT::Watchers->new($self->CurrentUser);
    $self->{'AdminCc'}->LimitToQueue($self->id);
    $self->{'AdminCc'}->LimitToType('AdminCc');
  }
  return($self->{'AdminCc'});
  
}
# }}}


# {{{ sub Cc
sub Cc {
  my $self = shift;
  if (! defined ($self->{'Cc'}) 
      || $self->{'Cc'}->{is_modified}) {
    require RT::Watchers;
    $self->{'Cc'} =RT::Watchers->new($self->CurrentUser);
    $self->{'Cc'}->LimitToQueue($self->id);
    $self->{'Cc'}->LimitToType('Cc');
  }
  return($self->{'Cc'});
  
}
# }}}


# {{{ sub Watchers 
sub Watchers  {
  my $self = shift;
  if (! defined ($self->{'Watchers'}) 
      || $self->{'Watchers'}->{is_modified}) {
    require RT::Watchers;
    $self->{'Watchers'} =RT::Watchers->new($self->CurrentUser);
    $self->{'Watchers'}->LimitToQueue($self->id);
  }
  return($self->{'Watchers'});
  
}
# }}}



# 
# Routines which deal with this queues acls 
#

#returns an EasySearch of ACEs everyone who has anything to do with this queue.
# {{{ sub ACL 
sub ACL  {
  my $self = shift;
  if (!$self->{'acl'}) {
    $self->{'acl'} = RT::ACL->new($self->{'self'});
    $user->{'acl'}->Limit(FIELD => 'queue', 
			  VALUE => "$self->id");
  }
  
 return ($self->{'acl'});
  
}
# }}}


#
# Really need to figure out how to do 
# acl lookups. perhaps the best thing to do is to extend easysearch to build an accessable hash of objects
#



#
#
 #
#ACCESS CONTROL
# 

# {{{ sub CreatePermitted 
sub CreatePermitted  {
  my $self = shift;
  if ($self->PermitNonmemberCreate ||
      $self->ModifyPermitted(@_)) { 
    return (1);
  }
  else {
    return (undef);
  }
}
# }}}

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
   my $actor = $self->CurrentUser;
 }
#  if ($self->Queue->DisplayPermitted($actor)) {
 if (1){   
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
    my $actor = $self->CurrentUser;
  }
  #  if ($self->Queue->ModifyPermitted($actor)) {
 
    return(1);
 
 # else {
    #if it's not permitted,
  #  return(0);
  #}
}
# }}}

# {{{ sub AdminPermitted 
sub AdminPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }


#  if ($self->ACL->AdminPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}


1;


