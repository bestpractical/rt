# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
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

use strict;
use vars qw/@ISA/;
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
  
  $self->CurrentUser($self);

}
# }}}

# {{{ sub Create

sub Create {
    my $self = shift;
    return (0, $self->loc('Permission Denied'));
}

# }}}

# {{{ sub Delete

sub Delete {
    my $self = shift;
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
	    $RT::Logger->err($self->loc("Couldn't load [_1] from the users database.\n", $self->Id));
	}
	
    }
    return ($self->{'UserObj'});
}
# }}}

# {{{ sub PrincipalObj 

=head2 PrincipalObj

    Returns this user's principal object.  this is just a helper routine for
    $self->UserObj->PrincipalObj

=cut

sub PrincipalObj {
    my $self = shift;
    return($self->UserObj->PrincipalObj);
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

    $identifier = RT::User::CanonicalizeEmailAddress(undef, $identifier);
        
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


# {{{ sub HasRight

=head2 HasRight

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
ok ($cu->loc('Before') eq "Avant", "Localized TEST_STRING into Frenc");

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
    return '' if $_[0] eq '';

    my $handle = $self->LanguageHandle;

    if (@_ == 1) {
	# pre-scan the lexicon hashes to return _AUTO keys verbatim,
	# to keep locstrings containing '[' and '~' from tripping over Maketext
	return $_[0] unless grep { exists $_->{$_[0]} } @{ $handle->_lex_refs };
    }

    return $handle->maketext(@_);
}

sub loc_fuzzy {
    my $self = shift;
    return '' if $_[0] eq '';

    # XXX: work around perl's deficiency when matching utf8 data
    return $_[0] if Encode::is_utf8($_[0]);
    my $result = $self->LanguageHandle->maketext_fuzzy(@_);

    return($result);
}
# }}}

eval "require RT::CurrentUser_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Vendor.pm});
eval "require RT::CurrentUser_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Local.pm});

1;
 
