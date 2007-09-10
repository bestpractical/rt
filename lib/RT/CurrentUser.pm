# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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

    use RT::CurrentUser;

    # laod
    my $current_user = new RT::CurrentUser;
    $current_user->load(...);
    # or
    my $current_user = RT::CurrentUser->new( $user_obj );
    # or
    my $current_user = RT::CurrentUser->new( $address || $name || $id );

    # manipulation
    $current_user->UserObj->set_Name('new_name');


=head1 DESCRIPTION

B<Read-only> subclass of L<RT::Model::User> class. Used to define the current
user. You should pass an instance of this class to constructors of
many RT classes, then the instance used to check ACLs and localize
strings.

=head1 METHODS

See also L<RT::Model::User> for a list of methods this class has.

=head2 new

Returns new CurrentUser object. Unlike all other classes of RT it takes
either subclass of C<RT::Model::User> class object or scalar value that is
passed to Load method.

=cut


package RT::CurrentUser;

use RT::I18N;

use strict;
use warnings;

use base qw/RT::Model::User Jifty::CurrentUser/;

#The basic idea here is that $self->current_user is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object
sub new {
    my $self = shift->SUPER::new(@_);
    my $User = shift;


    if ( defined $User ) {

        if ( UNIVERSAL::isa( $User, 'RT::Model::User' ) ) {
            $self->load_by_id( $User->id );
        }
        elsif ( ref $User ) {
            $RT::Logger->crit(
                "RT::CurrentUser->new() called with a bogus argument: $User");
        }
        else {
            $self->load( $User );
        }
    }

    return $self;
}

=head2 Create, Delete and Set*

As stated above it's a subclass of L<RT::Model::User>, but this class is read-only
and calls to these methods are illegal. Return 'permission denied' message
and log an error.

=cut

sub create {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

sub delete {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

sub _set {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

=head2 UserObj

Returns the L<RT::Model::User> object associated with this CurrentUser object.

=cut

sub UserObj {
    my $self = shift;

    my $user = RT::Model::User->new( $self );
    unless ( $user->load_by_id( $self->id ) ) {
        $RT::Logger->error(
            $self->loc("Couldn't load [_1] from the users database.\n", $self->id)
        );
    }
    return $user;
}


=head2 LoadByGecos

Loads a User into this CurrentUser object.
Takes a unix username as its only argument.

=cut

sub loadByGecos  {
    my $self = shift;
    return $self->load_by_cols( "Gecos", shift );
}

=head2 load_by_name

Loads a User into this CurrentUser object.
Takes a Name.

=cut

sub load_by_name {
    my $self = shift;
    return $self->load_by_cols( "Name", shift );
}

=head2 LanguageHandle

Returns this current user's langauge handle. Should take a language
specification. but currently doesn't

=cut 

sub LanguageHandle {
    my $self = shift;
    if (   !defined $self->{'LangHandle'}
        || !UNIVERSAL::can( $self->{'LangHandle'}, 'maketext' )
        || @_ )
    {
        if (   !$RT::SystemUser
            || !$RT::SystemUser->id
            || ( $self->id || 0 ) == $RT::SystemUser->id ) {
            @_ = qw(en-US);
        }
        elsif ( $self->id && $self->Lang ) {
            push @_, $self->Lang;
        }

        $self->{'LangHandle'} = RT::I18N->get_handle(@_);
    }

    # Fall back to english.
    unless ( $self->{'LangHandle'} ) {
        die "We couldn't get a dictionary. Ne mogu naidti slovar. No puedo encontrar dictionario.";
    }
    return $self->{'LangHandle'};
}

sub loc {
    my $self = shift;
    return '' if !defined $_[0] || $_[0] eq '';

    my $handle = $self->LanguageHandle;

    if (@_ == 1) {
        # pre-scan the lexicon hashes to return _AUTO keys verbatim,
        # to keep locstrings containing '[' and '~' from tripping over Maketext
        return $_[0] unless grep exists $_->{$_[0]}, @{ $handle->_lex_refs };
    }

    return $handle->maketext(@_);
}

sub loc_fuzzy {
    my $self = shift;
    return '' if !defined $_[0] || $_[0] eq '';

    # XXX: work around perl's deficiency when matching utf8 data
    return $_[0] if Encode::is_utf8($_[0]);

    return $self->LanguageHandle->maketext_fuzzy( @_ );
}

=head2 CurrentUser

Return the current currentuser object

=cut

sub CurrentUser {
    my $self = shift;
    return($self);

}

=head2 Authenticate

Takes $password, $Created and $nonce, and returns a boolean value
representing whether the authentication succeeded.

If both $nonce and $Created are specified, validate $password against:

    encode_base64(sha1(
        $nonce .
        $Created .
        sha1_hex( "$username:$realm:$server_pass" )
    ))

where $server_pass is the md5_hex(password) digest stored in the
database, $Created is in ISO time format, and $nonce is a random
string no longer than 32 bytes.

=cut

sub Authenticate { 
    my ($self, $password, $Created, $nonce, $realm) = @_;

    require Digest::MD5;
    require Digest::SHA1;
    require MIME::Base64;

    my $username = $self->UserObj->Name or return;
    my $server_pass = $self->UserObj->__value('Password') or return;
    my $auth_digest = MIME::Base64::encode_base64(Digest::SHA1::sha1(
        $nonce .
        $Created .
        Digest::MD5::md5_hex("$username:$realm:$server_pass")
    ));

    chomp($password);
    chomp($auth_digest);

    return ($password eq $auth_digest);
}

eval "require RT::CurrentUser_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Vendor.pm});
eval "require RT::CurrentUser_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/CurrentUser_Local.pm});

1;
