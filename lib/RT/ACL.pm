# $Header$
# Distributed under the terms of the GNU GPL
# Copyright (c) 2000 Jesse Vincent <jesse@fsck.com>

package RT::ACL;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);

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


# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::ACE;
  $item = new RT::ACE($self->CurrentUser);
  return($item);
}
# }}}

=head1 RT::ACL

Deals with collections of RT::ACE objects

=head1 Getting records out


=head2 Next

List off the ACL that's been specified

=head1 Limit the ACL to a specific scope

There are three real scopes right now:

=item Queue is for rights that apply to a single queue

=item AllQueues is for rights that apply to all queues

=item System is for rights that apply to the System (rights that aren't queue related)


=head2 LimitScopeToQueue

Takes a single queueid as its argument.

Limit the ACL to just a given queue when supplied with an integer queue id.

=cut

sub LimitScopeToQueue {
  my $self = shift;
  my $queue = shift;
  
  
  $self->Limit( FIELD =>'RightScope',
		VALUE => 'Queue');
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'RightAppliesTo',
	       VALUE => $queue );
  
}

=head2 LimitScopeToAllQueues

Takes no arguments
Limit the ACL to global queue rights. (Rights granted across all queues)

=cut

sub LimitScopeToAllQueues {
  my $self = shift;
  
  $self->Limit( FIELD =>'RightScope',
		VALUE => 'Queue');
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'RightAppliesTo',
	       VALUE => 0 );
}


=head2 LimitScopeToSystem()

Limit the ACL to system rights

=cut 

sub LimitScopeToSystem {
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
    $RT::Logger->debug("Now in ".$self."->_DoSearch");
    my $return = $self->SUPER::_DoSearch(@_);
    $self->_BuildHash();
    return ($return);
}


#Build a hash of this ACL's entries.
sub _BuildHash {
    my $self = shift;

    $RT::Logger->debug("Now in ".$self."->_BuildHash\n");
    while (my $entry = $self->Next) {
        $RT::Logger->debug("Now building entry for ".$entry ." in ".
                            $self."->_BuildHash\n");
        $self->{'as_hash'}->{$entry->RightScope . "-" .
                             $entry->RightAppliesTo . "-" . 
                             $entry->RightName . "-" .
                             $entry->PrincipalId . "-" .
                             $entry->PrincipalType
                            } = 1;

    }
    $RT::Logger->debug("Done with ".$self."->_BuildHash\n");
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

    $RT::Logger->debug("Now in ".$self."->HasEntry\n");
    use Data::Dumper;
    $RT::Logger->debug(Dumper($self->{'as_hash'}));
    $RT::Logger->debug("Trying to find as_hash-> ".
                            $args{'RightScope'} . "-" .
                             $args{'RightAppliesTo'} . "-" . 
                             $args{'RightName'} . "-" .
                             $args{'PrincipalId'} . "-" .
                             $args{'PrincipalType'}.
                           " as: '".
                            $self->{'as_hash'}->{
                              $args{'RightScope'} . "-" .
                              $args{'RightAppliesTo'} . "-" . 
                              $args{'RightName'} . "-" .
                              $args{'PrincipalId'} . "-" .
                              $args{'PrincipalType'}}. "'\n"
                             );
    return ($self->{'as_hash'}->{$args{'RightScope'} . "-" .
                             $args{'RightAppliesTo'} . "-" . 
                             $args{'RightName'} . "-" .
                             $args{'PrincipalId'} . "-" .
                             $args{'PrincipalType'}
                            } );

}

# }}}
1;
