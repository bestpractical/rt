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

RT::ACL is a subclass of DBIx::RecordSet

=head1 Getting records out
  
RT::ACL uses the standard DBIx::EasySearch mechanisms for getting data out
=head2 next

List off the ACL that's been specified (like any DBIx::RecordSet

=head1 Limit the ACL to a specific scope

There are three real scopes right now:

=item Queue is for rights that apply to a single queue

=item AllQueues is for rights that apply to all queues

=item System is for rights that apply to the System (rights that aren't queue related)


=head2 RT::ACL::LimitScopeToQueue($queue_id)

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

=head2 RT::ACL::LimitScopeToAllQueues()

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


=head2 RT::ACL::LimitScopeToSystem()

Limit the ACL to system rights

=cut 

sub LimitScopeToSystem {
  my $self = shift;
  
  $self->Limit( FIELD =>'RightScope',
		VALUE => 'System');
}


=head2 RT::ACL::LimitRightTo($right)

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

=head2 LimitPrincipalToUser($user_id)

Limit the ACL to a just a specific user

=cut

sub LimitPrincipalsToUser {
  my $self = shift;
  my $user = shift;
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalType',
	       VALUE => 'User' );
  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
	       FIELD => 'PrincipalId',
	       VALUE => $user );
  
}


=head2 LimitPrincipalToGroup($group_id)
  
Limit the ACL to just a specific group

=cut
  
sub LimitPrincipalsToGroup {
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

Limit the ACL to just a specific principal type

$type is one of:
  TicketOwner
  TicketRequestor
  TicketCc
  TicketAdminCc
  Everyone

=cut

sub LimitPrincipalsToType {
  my $self=shift;
  my $type=shift;  
  $self->Limit(ENTRYAGGREGATOR => 'OR',
		FIELD => 'PrincipalType',
		VALUE => $type );
}

1;
