# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
#
#

=head1 NAME

  RT::Group - RT's group object

=head1 SYNOPSIS

  use RT::Group;
my $group = new RT::Group($CurrentUser);

=head1 DESCRIPTION

An RT group object.

=head1 AUTHOR

Jesse Vincent, jesse@fsck.com

=head1 SEE ALSO

RT

=head1 METHODS

=cut


package RT::Group;
use RT::Record;
use vars qw|@ISA|;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
  my $self = shift; 
  $self->{'table'} = "Groups";
  return ($self->SUPER::_Init(@_));
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

# {{{ AddMember
# }}}

# {{{ HasMember
# }}}

# {{{ DeleteMember
# }}}

# {{{ ACL Related routines

# {{{ GrantQueueRight

=head2 GrantQueueRight

Grant a queue right to this group.  Takes a paramhash of which the elements
RightAppliesTo and RightName are important.

=cut

sub GrantQueueRight {
    
    my $self = shift;
    my %args = ( RightScope => 'Queue',
		 RightName => undef,
		 RightAppliesTo => undef,
		 PrincipalType => 'Group',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;

    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}

# }}}

# {{{ GrantSystemRight

=head2 GrantSystemRight

Grant a system right to this group. 
The only element that's important to set is RightName.

=cut
sub GrantSystemRight {
    
    my $self = shift;
    my %args = ( RightScope => 'System',
		 RightName => undef,
		 RightAppliesTo => 0,
		 PrincipalType => 'Group',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;

    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
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
