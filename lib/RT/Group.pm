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
		Description => 'read/write'
	       );
    return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub Create
sub Create {
    my $self = shift;
    die "RT::Group::Create unimplemented";
}
# }}}

# {{{ sub _Set
sub _Set {
    my $self = shift;
    if $self->CurrentUser->HasRight('ModifyGroups') {
	
	$self->$SUPER::_Set(@_);
    }
    else {
	return (0, "Permission Denied");
    }

}
# }}}
