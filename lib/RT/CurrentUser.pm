# $Header: /raid/cvsroot/rt/lib/RT/CurrentUser.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::CurrentUser - an RT object representing the current user

=head1 SYNOPSIS

  use RT::CurrentUser


=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::CurrentUser);

=end testing

=cut


package RT::CurrentUser;
use RT::Record;
use RT::I18N;

@ISA= qw(RT::Record);


# {{{ sub _Init 

#The basic idea here is that $self->CurrentUser is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object

sub _Init  {
  my $self = shift;
  my $Name = shift;

  $self->{'table'} = "Users";

  if (defined($Name)) {
    $self->Load($Name);
  }
  
  $self->_MyCurrentUser($self);

}
# }}}

# {{{ sub Create

sub Create {
    return (0, $self->loc('Permission Denied'));
}

# }}}

# {{{ sub Delete

sub Delete {
    return (0, $self->loc('Permission Denied'));
}

# }}}

# {{{ sub UserObj

=head2 UserObj

  Returns the RT::User object associated with this CurrentUser object.

=cut

sub UserObj {
    my $self = shift;
    
    unless ($self->{'UserObj'}) {
	use RT::User;
	$self->{'UserObj'} = RT::User->new($self);
	unless ($self->{'UserObj'}->Load($self->Id)) {
	    $RT::Logger->err(loc("Couldn't load [_1] from the users database.\n", $self->Id));
	}
	
    }
    return ($self->{'UserObj'});
}
# }}}


# {{{ sub PrincipalId 

=head2 PrincipalId

    Returns this user's principal Id.  this is just a helper routine for
    $self->UserObj->PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return($self->UserObj->PrincipalId);
}


# }}}


# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Name => 'read',
	      Gecos => 'read',
	      RealName => 'read',
	      Password => 'neither',
	      EmailAddress => 'read',
	      Privileged => 'read',
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

# {{{ sub LoadByGecos

=head2 LoadByGecos

Loads a User into this CurrentUser object.
Takes a unix username as its only argument.

=cut

sub LoadByGecos  {
    my $self = shift;
    my $identifier = shift;
        
    $self->LoadByCol("Gecos",$identifier);
    
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

# {{{ sub Privileged

=head2 Privileged

Returns true if the current user can be granted rights and be
a member of groups.

=cut

sub Privileged {
    my $self = shift;
    return ($self->UserObj->Privileged());
}

# }}}

# {{{ Convenient ACL methods

=head2 HasQueueRight

calls $self->UserObj->HasQueueRight with the arguments passed in

=cut

sub HasQueueRight {
	my $self = shift;
	return ($self->UserObj->HasQueueRight(@_));
}

=head2 HasSystemRight

calls $self->UserObj->HasSystemRight with the arguments passed in

=cut


sub HasSystemRight {
	my $self = shift;
	return ($self->UserObj->HasSystemRight(@_));
}
# }}}

# {{{ sub HasRight

=head2 HasSystemRight

calls $self->UserObj->HasRight with the arguments passed in

=cut

sub HasRight {
  my $self = shift;
  return ($self->UserObj->HasRight(@_));
}

# }}}

# {{{ Localization

=head2 LanguageHandle

Returns this current user's langauge handle. Should take a language
specification. but currently doesn't

=begin testing

ok (my $cu = RT::CurrentUser->new('root'));
ok (my $lh = $cu->LanguageHandle);
ok ($lh != undef);
ok ($lh->isa('Locale::Maketext'));
ok ($cu->loc('TEST_STRING') eq "Concrete Mixer", "Localized TEST_STRING into English");
ok ($lh = $cu->LanguageHandle('fr'));
ok ($cu->loc('TEST_STRING') eq "Feche la vache", "Localized TEST_STRING into Frenc");

=end testing

=cut 

sub LanguageHandle {
    my $self = shift;
    if  ((!defined $self->{'LangHandle'}) || 
         (!UNIVERSAL::can($self->{'LangHandle'}, 'maketext')) || 
         (@_))  {
        $self->{'LangHandle'} = RT::I18N->get_handle(@_);
    }
    # Fall back to english.
    unless ($self->{'LangHandle'}) {
        die "We couldn't get a dictionary. Nye mogu naidti slovar. No puedo encontrar dictionario.";
    }
    return ($self->{'LangHandle'});
}

sub loc {
    my $self = shift;
    return($self->LanguageHandle->maketext(@_));
}
# }}}


1;
 
