# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

=head1 NAME

  RT::GroupMember - a member of an RT Group

=head1 SYNOPSIS

  use RT::GroupMember;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::GroupMember;
use RT::Record;
use vars qw|@ISA|;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init {
  my $self = shift; 
  $self->{'table'} = "GroupMembers";
  return($self->SUPER::_Init(@_));
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
    if ( $self->CurrentUser->HasSystemRight('ModifyGroups')) {
	$RT::Logger->crit( "RT::GroupMember::Create unimplemented");
	return (undef);
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
    $RT::Logger->crit("RT::GroupMember::Delete unimplemented");
    
}
# }}}
# {{{ sub _Set
sub _Set {
    my $self = shift;
    if ($self->CurrentUser->HasSystemRight('ModifyGroups')) {
	
	$self->$SUPER::_Set(@_);
    }
    else {
	return (0, "Permission Denied");
    }

}
# }}}
