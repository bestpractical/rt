# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

=head1 NAME

  RT::GroupMember - a member of an RT Group

=head1 SYNOPSIS

RT::GroupMember should never be called directly. It should generally
only be accessed through the helper functions in RT::Group;

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

# a helper method for Add

sub Create {
    my $self = shift;
    my %args = ( GroupId => undef,
		 UserId => undef,
		 @_
	       );
    
    unless( $self->CurrentUser->HasSystemRight('ModifyGroups')) {
	return (0, 'Permission denied');
    }

    return ($self->SUPER::Create(GroupId => $args{'GroupId'},
				 UserId => $args{'UserId'}))
}
# }}}

# {{{ sub Add

=head2 Add

Takes a paramhash of UserId and GroupId.  makes that user a memeber
of that group

=cut

sub Add {
    my $self = shift;
    return ($self->Create(@_));
}
# }}}

# {{{ sub Delete

=head2 Delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

=cut

sub Delete {
    my $self = shift;
    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	return (0, 'Permission denied');
    }
    return($self->SUPER::Delete(@_));
}

# }}}

# {{{ sub UserObj

=head2 UserObj

Returns an RT::User object for the user specified by $self->UserId

=cut

sub UserObj {
    my $self = shift;
    unless (defined ($self->{'user_obj'})) {
        $self->{'user_obj'} = new RT::User($self->CurrentUser);
        $self->{'user_obj'}->Load($self->UserId);
    }
    return($self->{'user_obj'});
}

# {{{ sub _Set
sub _Set {
    my $self = shift;
    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	return (0, 'Permission denied');
    }
    return($self->SUPER::_Set(@_));
}
# }}}
