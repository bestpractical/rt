# $Header$
# Distributed under the terms of the GNU GPL
# Copyright (c) 2000 Jesse Vincent <jesse@fsck.com>

=head1 NAME

  RT::ACL - collection of RT ACE objects

=head1 SYNOPSIS

  use RT::ACL;
my $ACL = new RT::ACL($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::ACL;
use RT::EasySearch;
use RT::ACE;
@ISA= qw(RT::EasySearch);

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  $self->{'table'} = "ACL";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
  
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  return(RT::ACE->new($self->CurrentUser));
}
# }}}

=head2 Next

Hand out the next ACE that was found

=cut

# {{{ sub Next 
sub Next {
    my $self = shift;
    
    my $ACE = $self->SUPER::Next();
    if ((defined($ACE)) and (ref($ACE))) {
	
	if ( $ACE->CurrentUserHasRight('ShowACL') or
	     $ACE->CurrentUserHasRight('ModifyACL')
	   ) {
	    return($ACE);
	}
	
	#If the user doesn't have the right to show this ACE
	else {	
	    return($self->Next());
	}
    }
    #if there never was any ACE
    else {
	return(undef);
    }	
    
}

# }}}


=head1 Limit the ACL to a specific scope

There are two real scopes right now:

=item Queue is for rights that apply to a single queue

=item System is for rights that apply to the System (rights that aren't queue related)


=head2 LimitToQueue

Takes a single queueid as its argument.

Limit the ACL to just a given queue when supplied with an integer queue id.

=cut

sub LimitToQueue {
    my $self = shift;
    my $queue = shift;
    
    
    
    $self->Limit( FIELD =>'RightScope',
		  ENTRYAGGREGATOR => 'OR',
		  VALUE => 'Queue');
    $self->Limit( FIELD =>'RightScope',
		  ENTRYAGGREGATOR => 'OR',
		VALUE => 'Ticket');
    
    $self->Limit(ENTRYAGGREGATOR => 'OR',
		 FIELD => 'RightAppliesTo',
		 VALUE => $queue );
  
}


=head2 LimitToSystem()

Limit the ACL to system rights

=cut 

sub LimitToSystem {
  my $self = shift;
  
  $self->Limit( FIELD =>'RightScope',
		VALUE => 'System');
}


=head2 LimitRightTo

Takes a single RightName as its only argument.
Limits the search to the right $right.
$right is a right listed in perldoc RT::ACE

=cut

sub LimitRightTo {
  my $self = shift;
  my $right = shift;
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'RightName',
	       VALUE => $right );
  
}

=head1 Limit to a specifc set of principals

=head2 LimitPrincipalToUser

Takes a single userid as its only argument.
Limit the ACL to a just a specific user.

=cut

sub LimitPrincipalToUser {
  my $self = shift;
  my $user = shift;
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalType',
	       VALUE => 'User' );
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalId',
	       VALUE => $user );
  
}


=head2 LimitPrincipalToGroup

Takes a single group as its only argument.
Limit the ACL to just a specific group.

=cut
  
sub LimitPrincipalToGroup {
  my $self = shift;
  my $group = shift;
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalType',
	       VALUE => 'Group' );

  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalId',
	       VALUE => $group );

}

=head2 LimitPrincipalToType($type)

Takes a single argument, $type.
Limit the ACL to just a specific principal type

$type is one of:
  TicketOwner
  TicketRequestor
  TicketCc
  TicketAdminCc
  Everyone
  User
  Group

=cut

sub LimitPrincipalToType {
  my $self=shift;
  my $type=shift;  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
		FIELD => 'PrincipalType',
		VALUE => $type );
}


=head2 LimitPrincipalToId 

Takes a single argument, the numeric Id of the principal to limit this ACL to. Repeated calls to this 
function will broaden the scope of the search to include all principals listed.

=cut

sub LimitPrincipalToId {
    my $self = shift;
    my $id = shift;

    if ($id =~ /^\d+$/) {
	$self->Limit(ENTRYAGGREGATOR => 'OR',
		     FIELD => 'PrincipalId',
		     VALUE => $id );
    }
    else {
	$RT::Logger->warn($self."->LimitPrincipalToId called with '$id' as an id");
	return undef;
    }
}


#wrap around _DoSearch  so that we can build the hash of returned
#values 
sub _DoSearch {
    my $self = shift;
   # $RT::Logger->debug("Now in ".$self."->_DoSearch");
    my $return = $self->SUPER::_DoSearch(@_);
  #  $RT::Logger->debug("In $self ->_DoSearch. return from SUPER::_DoSearch was $return\n");
    $self->_BuildHash();
    return ($return);
}


#Build a hash of this ACL's entries.
sub _BuildHash {
    my $self = shift;

    while (my $entry = $self->Next) {
       my $hashkey = $entry->RightScope . "-" .
                             $entry->RightAppliesTo . "-" . 
                             $entry->RightName . "-" .
                             $entry->PrincipalId . "-" .
                             $entry->PrincipalType;

        $self->{'as_hash'}->{"$hashkey"} =1;

    }
}


# {{{ HasEntry

=head2 HasEntry

=cut

sub HasEntry {

    my $self = shift;
    my %args = ( RightScope => undef,
                 RightAppliesTo => undef,
                 RightName => undef,
                 PrincipalId => undef,
                 PrincipalType => undef,
                 @_ );

    #if we haven't done the search yet, do it now.
    $self->_DoSearch();

    if ($self->{'as_hash'}->{ $args{'RightScope'} . "-" .
			      $args{'RightAppliesTo'} . "-" . 
			      $args{'RightName'} . "-" .
			      $args{'PrincipalId'} . "-" .
			      $args{'PrincipalType'}
                            } == 1) {
	return(1);
    }
    else {
	return(undef);
    }
}

# }}}
1;
