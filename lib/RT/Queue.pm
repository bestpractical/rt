#$Header$

package RT::Queue;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "queues";
  $self->_Init(@_);
  return ($self);
}

sub _Accessible {
  my $self = shift;
  my %Cols = ( QueueId => 'read/write',
	       CorrespondAddress => 'read/write',
	       CommentAddress =>  'read/write',
	       MailOwnerOnTransaction =>  'read/write',
	       MailMembersOnTransaction =>  'read/write',
	       MailRequestorOnTransaction =>  'read/write',
	       MailRequestorOnCreation =>  'read/write',
	       MailMembersOnCorrespondence => 'read/write',	
	       MailMembersOnComment =>  'read/write',
	       PermitNonmemberCreate =>  'read/write',
	       InitialPriority =>  'read/write',
	       FinalPriority =>  'read/write',
	       DefaultDueIn =>  'read/write'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

sub create {
  my $self = shift;

#  print STDERR "In RT::Queue::create.pm\n";
  my $id = $self->SUPER::Create(QueueId => @_);
#  print STDERR "Loading $id\n";
  $self->LoadById($id);
  
}


sub delete {
  my $self = shift;
 # this function needs to move all requests into some other queue!
  my ($query_string,$update_clause);
  
  die ("Queue->Delete not implemented yet");
    
    
    if (($users{$in_current_user}{'admin_rt'}) or ($queues{"$in_queue_id"}{'acls'}{"$in_current_user"}{'admin'})) {
      

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

sub Create {
  my $self = shift;
  #print "In RT::Queue::Create\n";
  return($self->create(@_));
}


sub Load {
  my $self = shift;
  my $queue_id = shift;
  $self->SUPER::LoadByCol("QueueId", $queue_id);
}

sub load {
  my $self = shift;
  return($self->Load(@_));
}


#
# Distribution lists

sub DistributionList {
	my $self = shift;
	#return the list of all queue members.
	return();
      }

#


#
# Routines related to areas
# Eventually, this may be replaced with a keyword system

sub NewArea {
}

sub DeleteArea {
}

sub Areas {
  my $self = shift;
  
  if (!$self->{'areas'}){
    require RT::Areas;
    $self->{'areas'} = RT::Areas->new($self->CurrentUser);
    $self->{'areas'}->Limit(FIELD => 'queue',
			    VALUE => $self->QueueId);
  }  
  #returns an EasySearch object which enumerates this queue's areas
}

#
# 
# Routines which deal with this queues acls 
#

#returns an EasySearch of ACEs everyone who has anything to do with this queue.
sub ACL {
  my $self = shift;
  if (!$self->{'acl'}) {
    $self->{'acl'} = RT::ACL->new($self->{'self'});
    $user->{'acl'}->Limit(FIELD => 'queue', 
			  VALUE => "$self->id");
  }
  
 return ($self->{'acl'});
  
}


#
# Really need to figure out how to do 
# acl lookups. perhaps the best thing to do is to extend easysearch to build an accessable hash of objects
#



#
#
 #
#ACCESS CONTROL
# 
sub DisplayPermitted {
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
sub ModifyPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
#  if ($self->Queue->ModifyPermitted($actor)) {
 if (1) {   
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


#  if ($self->ACL->AdminPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}


1;


