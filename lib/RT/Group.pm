# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
#
#
package RT::Group;
use RT::Record;
use vars qw|@ISA|;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  
  $self->{'table'} = "Groups";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = (
		Name => 'read/write',
		Description => 'read/write',
		Pseudo => 'read'
	       );
    return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub Create

=head2 Create

Takes a paramhash with three named arguments: Name, Description and Pseudo.
Pseudo is used internally by RT for certain special ACL decisions.

=cut

sub Create {
    my $self = shift;
    my %args = ( Name => undef,
		 Description => undef,
		 Pseudo => 0,
		 @_);
    
    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	$RT::Logger->warning($self->CurrentUser->UserId ." Tried to create a group without permission.");
	return(undef);
    }
    
    my $retval = $self->SUPER::Create(Name => $args{'Name'},
				      Description => $args{'Description'},
				      Pseudo => $args{'Pseudo'});
    return ($retval);
}
# }}}


# {{{ sub _Set
sub _Set {
    my $self = shift;
    if ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	
	$self->$SUPER::_Set(@_);
    }
    else {
	return (0, "Permission Denied");
    }

}
# }}}
