# $Header$
# Distributed under the terms of the GNU GPL
# Copyright (c) 2000 Jesse Vincent <jesse@fsck.com>

package RT::ACL;
use DBIx::EasySearch;
@ISA= qw(DBIx::EasySearch);

my @TicketRights = qw(Destroy Display Update Resolve


# {{{ sub new 
sub new  {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "ACL";
  $self->{'primary_key'} = "id";
  return($self);
}
# }}}

# {{{ sub Limit 
sub Limit  {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub LimitToQueueACL

sub LimitToQueueACL {
}

# }}}


# {{{ sub LimitPrincipals
sub LimitPrincipals {
  my $self = shift;
  my $user = shift;
  my $ticket = shift;
  
  $self->LimitPrinicpalsToUser($user);
  $self->LimitPrincipalsToWatchers($user);
  if (defined $self->Ticket) {
    $self->LimitPrincipalsToOwner($user, $ticket);
  }
  
}
# }}}

# {{{ sub LimitPrinicpalsToUser 

sub LimitPrincipalsToUser {
  my $self = shift;
  my $user = shift;
  
  
  return (" ( ACE.PrincipalScope = 'User') AND 
	    ( ACE.PrincipalId = $user OR ACE.PrincipalId = 0))");
}

# }}}

# {{{ sub LimitPrincipalsToOwner
sub LimitPrincipalsToOwner {
  my $self = shift;
  my $user = shift;
  my $ticket = shift
  return (" ( ACE.PrinciaplScope = 'Owner') AND ( Tickets.Owner = $user ) AND ( Tickets.Id = $ticket)");
}
# }}}

# {{{ sub LimitPrincipalsToWatchers
sub LimitPrincipalsToWatchers {
  my $self = shift;
  my $user = shift;
  return ("( ACE.PrincipalScope = Watchers.Scope ) AND 
           ( ACE.PrincipalType = Watchers.Type ) AND 
           ( ACL.PrincipalId = Watchers.Value ) AND 
  	   ( Watchers.Owner = $User )");
}

# }}}

# {{{ sub LimitToQueueObjects 
sub LimitToQueueObjects {
  my $self = shift;
  my $queue = shift if (@_);
  
  $QueueObject = "(ACE.ObjectType = 'Queue') and ( ACE.ObjectId = 0";
  if (defined $queue) {
    $QueueObject .= "OR ACE.ObjectId = ".$self->quote($queue) ;
  }
  
  $QueueObject .= ")";
 
  return ("($QueueObject)");
}

# }}}

# This select statement would figure out if A user has $Right at the queue level

SELECT ACE.id from ACE, Watchers, Tickets WHERE ( 
	     $QueueObject
	     AND ( ACE.Right = $Right) 
	     AND ($Principals))

# This select statement would figure outif a user has $Right for the "System"

SELECT ACE.id from ACE, Watchers, Tickets WHERE ( 
	     ($SystemObject) AND ( ACE.Right = $Right ) AND ($Principals))


# {{{ sub LimitToRight 
sub LimitToRight {
  my $self = shift;
  my $right = shift;
  my $RightClause = "(ACE.Right = ."$self->quote($right)".)";
}  
# }}}

# {{{ sub LimitToSystemObjects
sub LimitToSystemObjects {
  my $self = shift;
  
  $SystemObject = "( ACE.ObjectType = 'System' )";

}

# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  $item = new RT::ACE($self->CurrentUser, $Handle);
  return($item);
}
# }}}


#does this apply to a queue or something else
sub Scope {
  my $self = shift;
  my $scope =shift;
}
		    

#if you're concerned about queue level rights, specify the queue
sub AppliesTo {
  my $self = shift;
  my $AppliesTo = shift;
}

#if you're concerned about ticket_level rights,  specify the ticket
sub TicketIs {
my $self = shift;
my $TicketObj = shift;


}

sub PrincipalTypeIs {
my $self = shift;
#principal type is one of 
#User,<userid>
#Group,<groupip>
#TicketOwner,NULL
#TicketRequestor,NULL
#TicketCc,NULL
#TicketAdminCc,NULL
#Everyone,NULL
}
sub PrincipalIdIs {
my $self = shift;
#principal is a userid.  
my $PrincipalObj = shift;
}

sub RightIs {
my $self = shift;
#right is a textual identifier of a right;
my $right = shift;



}

sub IsPermitted {
my $self = shift;
#this code will DTRT and figure out if  
#the principal is a member of any relevant groups, such as ticket watchers
# or rt's eventual groups system. 





#return(1) if permitted;
#return(undef) otherwise;
}


1;



