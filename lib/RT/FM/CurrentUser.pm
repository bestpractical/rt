# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

# $Header: /raid/cvsroot/fm/lib/RT/FM/CurrentUser.pm,v 1.1 2001/09/09 07:19:58 jesse Exp $
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::FM::CurrentUser - an RT object representing the current user

=head1 SYNOPSIS

  use RT::FM::CurrentUser


=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::FM::CurrentUser;
use RT::FM::Record;
@ISA= qw(RT::FM::Record);


# {{{ sub _Init 

#The basic idea here is that $self->CurrentUser is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object

sub _Init  {
  my $self = shift;
  my $Name = shift;

  $self->{'table'} = "User";

  if (defined($Name)) {
    $self->Load($Name);
  }
  
  $self->_MyCurrentUser($self);

}
# }}}

# {{{ sub Create

sub Create {
    return (0, 'Permission Denied');
}

# }}}

# {{{ sub Delete

sub Delete {
    return (0, 'Permission Denied');
}

# }}}

# {{{ sub UserObj

=head2 UserObj

  Returns the RT::FM::User object associated with this CurrentUser object.

=cut

sub UserObj {
    my $self = shift;
    
    unless ($self->{'UserObj'}) {
	use RT::FM::User;
	$self->{'UserObj'} = RT::FM::User->new($self);
	unless ($self->{'UserObj'}->Load($self->Id)) {
		warn "Couldn't load user";
	}
	
    }
    return ($self->{'UserObj'});
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Name => 'read',
	      RealName => 'read',
	      Password => 'neither',
	      EmailAddress => 'read',
	      IsEditor => 'read',
	      IsAdministrator => 'read'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub LoadByEmail

=head2 LoadByEmail

Loads a User into this CurrentUser object.
Takes the email address of the user to load.

=cut

sub LoadByEmail  {
    my $self = shift;
    my $identifier = shift;
        
    $self->LoadByCol("EmailAddress",$identifier);
    
}
# }}}

# {{{ sub LoadByName

=head2 LoadByName

Loads a User into this CurrentUser object.
Takes a Name.
=cut

sub LoadByName {
    my $self = shift;
    my $identifier = shift;
    $self->LoadByCol("Name",$identifier);
    
}
# }}}

# {{{ sub Load 

=head2 Load

Loads a User into this CurrentUser object.
Takes either an integer (users id column reference) or a Name
The latter is deprecated. Instead, you should use LoadByName.
Formerly, this routine also took email addresses. 

=cut

sub Load  {
  my $self = shift;
  my $identifier = shift;

  #if it's an int, load by id. otherwise, load by name.
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
      # This is a bit dangerous, we might get false authen if somebody
      # uses ambigous userids or real names:
      $self->LoadByCol("Name",$identifier);
  }
}

# }}}

# {{{ sub IsPassword

=head2 IsPassword

Takes a password as a string.  Passes it off to IsPassword in this
user's UserObj.  If it is the user's password and the user isn't
disabled, returns 1.

Otherwise, returns undef.

=cut

sub IsPassword { 
  my $self = shift;
  my $value = shift;
  
  return ($self->UserObj->IsPassword($value)); 
}

# }}}


1;
 
