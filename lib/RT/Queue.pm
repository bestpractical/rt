#$Header$

package RT::Queue;
use RT::Record;
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
#  print STDERR "MKIA::Article::create::",join(", ",@_),"\n";
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
  return($self->create(@_));
}


sub Load {
  my $self = shift;
  my $queue_id = shift;
  $self->SUPER::load_by_col("QueueId", $queue_id);
}

sub load {
  my $self = shift;
  return($self->Load(@_));
}

sub CorrespondAddress {
  my $self = shift;
  $self->_set_and_return('CorrespondAddress',@_);
}

sub QueueId {
  my $self = shift;
  $self->_set_and_return('QueueId');
  
}

sub id {
  my $self = shift;
  return($self->id);
}
sub CommentAddress {
  my $self = shift;
  $self->_set_and_return('CommentAddress',@_);
}



sub StartingPriority {
  my $self = shift;
  $self->_set_and_return('StartingPriority',@_);
}
sub FinalPriority {
  my $self = shift;
  $self->_set_and_return('FinalPriority',@_);
}

sub PermitNonmemberCreate {
  my $self = shift;
  $self->_set_and_return('PermitNonmemberCreate',@_);
}



sub MailOwnerOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailOwnerOnTransaction',@_);
}

sub MailMembersOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailMembersOnTransaction',@_);
}

sub MailRequestorOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailRequestorOnTransaction',@_);
}
sub MailRequestorOnCreation {
  my $self = shift;
  $self->_set_and_return('MailRequestorOnCreation',@_);
}

sub MailMembersOnCorrespondence {
  my $self = shift;
  $self->_set_and_return('MailMembersOnCorrespondence',@_);
}

sub MailMembersOnComment {
  my $self = shift;
  $self->_set_and_return('MailMembersOnComment',@_);
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
   $self->{'acl'} = RT::ACL->new($self->{'user'});
   $self->{'acl'}->Limit(FIELD => 'queue', 
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
sub Display_Permitted {
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
sub Modify_Permitted {
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

sub Admin_Permitted {
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


