# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
#
#
package RT::GroupMember;
use RT::Record;
use vars qw|@ISA|;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  
  $self->{'table'} = "GroupMembers";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = (
		GroupId => 'read',
		UserId => 'read'
		);

    return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub Create
sub Create {
    my $self = shift;
    if $self->CurrentUser->HasSystemRight('ModifyGroups') {
	die "RT::GroupMember::Create unimplemented";
    }
    else {
	return (0,'Permission Denied');
    }
    
}
# }}}

# {{{ sub Add
sub Add {
    return ($self->Create(@_));
}
# }}}

# {{{ sub Delete
#TODO this routine should delete the currently loaded GroupMember
sub Delete {
    my $self = shift;
    die "RT::GroupMember::Delete unimplemented"
    
}
# }}}
# {{{ sub _Set
sub _Set {
    my $self = shift;
    if $self->CurrentUser->HasSystemRight('ModifyGroups') {
	
	$self->$SUPER::_Set(@_);
    }
    else {
	return (0, "Permission Denied");
    }

}
# }}}
