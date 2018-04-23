# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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

    use RT::CurrentUser;

    # load
    my $current_user = RT::CurrentUser->new;
    $current_user->Load(...);
    # or
    my $current_user = RT::CurrentUser->new( $user_obj );
    # or
    my $current_user = RT::CurrentUser->new( $address || $name || $id );

    # manipulation
    $current_user->UserObj->SetName('new_name');


=head1 DESCRIPTION

B<Read-only> subclass of L<RT::User> class. Used to define the current
user. You should pass an instance of this class to constructors of
many RT classes, then the instance used to check ACLs and localize
strings.

=head1 METHODS

See also L<RT::User> for a list of methods this class has.

=head2 new

Returns new CurrentUser object. Unlike all other classes of RT it takes
either subclass of C<RT::User> class object or scalar value that is
passed to Load method.

=cut


package RT::CurrentUser;

use strict;
use warnings;

use base qw/RT::User/;

use RT::I18N;

#The basic idea here is that $self->CurrentUser is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object

sub _Init {
    my $self = shift;
    my $User = shift;

    $self->{'table'} = "Users";

    if ( defined $User ) {

        if ( UNIVERSAL::isa( $User, 'RT::User' ) ) {
            $self->LoadById( $User->id );
        }
        elsif ( ref $User ) {
            $RT::Logger->crit(
                "RT::CurrentUser->new() called with a bogus argument: $User");
        }
        else {
            $self->Load( $User );
        }
    }

    $self->_BuildTableAttributes;

}

=head2 Create, Delete and Set*

As stated above it's a subclass of L<RT::User>, but this class is read-only
and calls to these methods are illegal. Return 'permission denied' message
and log an error.

=cut

sub Create {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

sub Delete {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

sub _Set {
    my $self = shift;
    $RT::Logger->error('RT::CurrentUser is read-only, RT::User for manipulation');
    return (0, $self->loc('Permission Denied'));
}

=head2 UserObj

Returns the L<RT::User> object associated with this CurrentUser object.

=cut

sub UserObj {
    my $self = shift;

    my $user = RT::User->new( $self );
    unless ( $user->LoadById( $self->Id ) ) {
        $RT::Logger->error("Couldn't load " . $self->Id . " from the users database.");
    }
    return $user;
}

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

=head2 LoadByGecos

Loads a User into this CurrentUser object.
Takes a unix username as its only argument.

=cut

sub LoadByGecos  {
    my $self = shift;
    return $self->LoadByCol( "Gecos", shift );
}

=head2 LoadByName

Loads a User into this CurrentUser object.
Takes a Name.

=cut

sub LoadByName {
    my $self = shift;
    return $self->LoadByCol( "Name", shift );
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
        if ( my $lang = $self->Lang ) {
            push @_, $lang;
        }
        elsif ( $self->id && ($self->id == (RT->SystemUser->id||0) || $self->id == (RT->Nobody->id||0)) ) {
            # don't use ENV magic for system users
            push @_, 'en';
        } elsif ($HTML::Mason::Commands::m) {
            # Detect from the HTTP header.
            require I18N::LangTags::Detect;
            push @_, I18N::LangTags::Detect->http_accept_langs(
                RT::Interface::Web::RequestENV('HTTP_ACCEPT_LANGUAGE')
            );
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
        # If we have no [_1] replacements, and the key does not appear
        # in the lexicon, unescape (using ~) and return it verbatim, as
        # an optimization.
        my $unescaped = $_[0];
        $unescaped =~ s!~(.)!$1!g;
        return $unescaped unless grep exists $_->{$_[0]}, @{ $handle->_lex_refs };
    }

    return $handle->maketext(@_);
}

sub loc_fuzzy {
    my $self = shift;
    return '' if !defined $_[0] || $_[0] eq '';

    return $self->LanguageHandle->maketext_fuzzy( @_ );
}

=head2 CurrentUser

Return the current currentuser object

=cut

sub CurrentUser {
    return shift;
}

sub CustomFieldLookupType {
    return "RT::User";
}

RT::Base->_ImportOverlays();

1;
