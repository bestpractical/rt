# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
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
use base qw/RT::Record/;

# {{{ sub _Init 

#The basic idea here is that $self->CurrentUser is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object

sub _Init {
    my $self = shift;
    my $User = shift;

    $self->{'table'} = "Users";

    if ( defined($User) ) {

        if (   UNIVERSAL::isa( $User, 'RT::User' )
            || UNIVERSAL::isa( $User, 'RT::CurrentUser' ) )
        {
            $self->Load( $User->id );

        }
        elsif ( ref($User) ) {
            $RT::Logger->crit(
                "RT::CurrentUser->new() called with a bogus argument: $User");
        }
        else {
            $self->Load($User);
        }
    }

    $self->_BuildTableAttributes();

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
    
	use RT::User;
	my $user = RT::User->new($self);

	unless ($user->Load($self->Id)) {
	    $RT::Logger->err($self->loc("Couldn't load [_1] from the users database.\n", $self->Id));
	}
    return ($user);
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


 sub _CoreAccessible  {
     {
         Name           => { 'read' => 1 },
           Gecos        => { 'read' => 1 },
           RealName     => { 'read' => 1 },
           Lang     => { 'read' => 1 },
           Password     => { 'read' => 0, 'write' => 0 },
          EmailAddress => { 'read' => 1, 'write' => 0 }
     };
  
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

  elsif (UNIVERSAL::isa($identifier,"RT::User")) {
         # DWIM if they pass a user in
         $self->SUPER::LoadById($identifier->Id);
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
ok (my $lh = $cu->LanguageHandle('en-us'));
ok (defined $lh);
ok ($lh->isa('Locale::Maketext'));
is ($cu->loc('TEST_STRING'), "Concrete Mixer", "Localized TEST_STRING into English");
ok ($lh = $cu->LanguageHandle('fr'));
SKIP: {
    skip "fr locale is not loaded", 1 unless grep $_ eq 'fr', @RT::LexiconLanguages;
    is ($cu->loc('Before'), "Avant", "Localized TEST_STRING into Frenc");
}

=end testing

=cut 

sub LanguageHandle {
    my $self = shift;
    if (   ( !defined $self->{'LangHandle'} )
        || ( !UNIVERSAL::can( $self->{'LangHandle'}, 'maketext' ) )
        || (@_) ) {
        if ( !$RT::SystemUser or ($self->id || 0) == $RT::SystemUser->id() ) {
            @_ = qw(en-US);
        }

        elsif ( $self->Lang ) {
            push @_, $self->Lang;
        }
        $self->{'LangHandle'} = RT::I18N->get_handle(@_);
    }

    # Fall back to english.
    unless ( $self->{'LangHandle'} ) {
        die "We couldn't get a dictionary. Nye mogu naidti slovar. No puedo encontrar dictionario.";
    }
    return ( $self->{'LangHandle'} );
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
    return '' if (!$_[0] ||  $_[0] eq '');

    # XXX: work around perl's deficiency when matching utf8 data
    return $_[0] if Encode::is_utf8($_[0]);
    my $result = $self->LanguageHandle->maketext_fuzzy(@_);

    return($result);
}
# }}}


=head2 CurrentUser

Return  the current currentuser object

=cut

sub CurrentUser {
    my $self = shift;
    return($self);

}

=head2 Authenticate

Takes $password, $created and $nonce, and returns a boolean value
representing whether the authentication succeeded.

If both $nonce and $created are specified, validate $password against:

    encode_base64(sha1(
	$nonce .
	$created .
	sha1_hex( "$username:$realm:$server_pass" )
    ))

where $server_pass is the md5_hex(password) digest stored in the
database, $created is in ISO time format, and $nonce is a random
string no longer than 32 bytes.

=cut

sub Authenticate { 
    my ($self, $password, $created, $nonce, $realm) = @_;

    require Digest::MD5;
    require Digest::SHA1;
    require MIME::Base64;

    my $username = $self->UserObj->Name or return;
    my $server_pass = $self->UserObj->__Value('Password') or return;
    my $auth_digest = MIME::Base64::encode_base64(Digest::SHA1::sha1(
	$nonce .
	$created .
	Digest::MD5::md5_hex("$username:$realm:$server_pass")
    ));

    chomp($password);
    chomp($auth_digest);

    return ($password eq $auth_digest);
}

# }}}


eval "require RT::CurrentUser_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Vendor.pm});
eval "require RT::CurrentUser_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Local.pm});

1;
 
