# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Users;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  $self->{'table'} = "Users";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
  
}
# }}}
# {{{ sub Limit 
# Why do we need this?  I thought "AND" was default, anyway?
sub Limit  {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
# What is this?
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  $item = new RT::User($self->CurrentUser);
  return($item);
}
# }}}

=head2 LimitToEmail

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub LimitToEmail {
    my $self=shift;
    my $addr=shift
    $self->Limit(FIELD => 'EmailAddress', VALUE => "$addr");
}


# {{{ MemberOfGroup

=head2 MemberOfGroup

takes one argument, a group id number. Limits the returned set
to members of a given group

=cut

sub MemberOfGroup {
    my $self = shift;
    my $group = shift;
    
    return ("No group specified") if (!defined $group);

    my $groupalias = $self->NewAlias('GroupMembers');

    $self->Join( ALIAS1 => 'main', FIELD1 => 'id', 
		 ALIAS2 => "$groupalias", FIELD2 => 'UserId');
    
    $self->Limit (ALIAS => "$groupalias",
		  FIELD => 'GroupId',
		  VALUE => "$group",
		  OPERATOR => "="
		 );
}

# }}}



=head2 Disabled

Limits the returned set to users who have been disabled

=cut

sub Disabled {
    my $self = shift;
    $self->Limit( FIELD => 'Disabled',
		  OPERATOR => '=',
		  VALUE=> '1');
}


=head2 LimitToCanManipulate

Limits to users who can be made members of ACLs and groups

=cut

# {{{ HasQueueRight

=head2 HasQueueRight

Takes a queue id as its first argument.  Queue Id "0" is treated by RT as "applies to all queues"
Takes a specific right as an optional second argument

Limits the returned set to users who have rights in the queue specified, personally.  If the optional second argument is supplied, limits to users who have been explicitly granted that right.



This should not be used as an ACL check, but only for obtaining lists of
users with explicit rights in a given queue.

=cut

sub HasQueueRight {
    my $self = shift;
    my $queue = shift;
    my $right;
    
    $right = shift if (@_);


    my $acl_alias  = $self->NewAlias('ACL');
    $self->Join( ALIAS1 => 'main',  FIELD1 => 'id',
		 ALIAS2 => $acl_alias, FIELD2 => 'PrincipalId');
    $self->Limit (ALIAS => $acl_alias,
		 FIELD => 'PrincipalType',
		 OPERATOR => '=',
		 VALUE => 'User');


    $self->Limit(ALIAS => $acl_alias,
		 FIELD => 'RightAppliesTo'
		 OPERATOR => '=',
		 VALUE => "$queue");


    $self->Limit(ALIAS => $acl_alias,
		 FIELD => 'RightScope'
		 OPERATOR => '=',
		 ENTRYAGGREGATOR => 'OR'
		 VALUE => 'Queue');


    $self->Limit(ALIAS => $acl_alias,
		 FIELD => 'RightScope'
		 OPERATOR => '=',
		 ENTRYAGGREGATOR => 'OR'
		 VALUE => 'Ticket');


    #TODO: is this being initialized properly if the right isn't there?
    if (defined ($right)) {
	
	$self->Limit(ALIAS => $acl_alias,
		     FIELD => 'RightName'
		     OPERATOR => '=',
		     VALUE => "$right");
	
	
       );


}



# }}}


# {{{ HasSystemRight

=head2 HasSystemRight

Takes one optional argument:
   The name of a System level right.

Limits the returned set to users who have been granted system rights, personally.  If the optional argument is passed in, limits to users who have been granted the explicit right listed.   Please see the note attached to LimitToQueueRights

=cut

sub HasSystemRight {
    my $self = shift;
    my $right = shift if (@_);
       my $acl_alias  = $self->NewAlias('ACL');


    $self->Join( ALIAS1 => 'main',  FIELD1 => 'id',
		 ALIAS2 => $acl_alias, FIELD2 => 'PrincipalId');
    $self->Limit (ALIAS => $acl_alias,
		 FIELD => 'PrincipalType',
		 OPERATOR => '=',
		 VALUE => 'User');

    $self->Limit(ALIAS => $acl_alias,
		 FIELD => 'RightScope'
		 OPERATOR => '=',
		 VALUE => 'System');


    #TODO: is this being initialized properly if the right isn't there?
    if (defined ($right)) {
	$self->Limit(ALIAS => $acl_alias,
		     FIELD => 'RightName'
		     OPERATOR => '=',
		     VALUE => "$right");
	
       );
    
}

# }}}

1;

