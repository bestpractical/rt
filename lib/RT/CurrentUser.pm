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

=head1 name

  RT::CurrentUser - an RT object representing the current user

=head1 SYNOPSIS

    use RT::CurrentUser;

    # laod
    my $current_user = RT::CurrentUser->new;
    $current_user->load(...);
    # or
    my $current_user = RT::CurrentUser->new( $user_obj );
    # or
    my $current_user = RT::CurrentUser->new( $address || $name || $id );

    # manipulation
    $current_user->user_object->set_name('new_name');


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

use base qw/Jifty::CurrentUser/;

=head2 Create, Delete and Set*

As stated above it's a subclass of L<RT::Model::User>, but this class is read-only
and calls to these methods are illegal. Return 'permission denied' message
and log an error.

=cut

sub create {
    my $self = shift;
    Jifty->log->error(
        'RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return ( 0, _('Permission Denied') );
}

sub delete {
    my $self = shift;
    Jifty->log->error(
        'RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return ( 0, _('Permission Denied') );
}

sub _set {
    my $self = shift;
    Jifty->log->error(
        'RT::CurrentUser is read-only, RT::Model::User for manipulation');
    return ( 0, _('Permission Denied') );
}

=head2 LoadByGecos

Loads a User into this CurrentUser object.
Takes a unix username as its only argument.

=cut

sub load_by_gecos {
    my $self = shift;
    return $self->new( "Gecos", shift );
}

=head2 load_by_name

Loads a User into this CurrentUser object.
Takes a name.

=cut

sub load_by_name {
    my $self = shift;
    return $self->new( "name", shift );
}

=head2 CurrentUser

Return the current currentuser object

=cut

sub current_user {
    my $self = shift;
    return ($self);

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

sub authenticate {
    my ( $self, $password, $Created, $nonce, $realm ) = @_;

    require Digest::MD5;
    require Digest::SHA1;
    require MIME::Base64;

    my $username    = $self->user_object->name                or return;
    my $server_pass = $self->user_object->__value('password') or return;
    my $auth_digest = MIME::Base64::encode_base64(
        Digest::SHA1::sha1(
                  $nonce 
                . $Created
                . Digest::MD5::md5_hex("$username:$realm:$server_pass")
        )
    );

    chomp($password);
    chomp($auth_digest);

    return ( $password eq $auth_digest );
}

sub has_right {
    my $self = shift;
    return 1 if ( $self->is_superuser );
    $self->user_object->has_right(@_);
}

sub superuser {
    my $self = shift;
    return RT->system_user;
}

sub email { shift->user_object->email }
sub name  { shift->user_object->name }

sub principal_object {
    my $self = shift;
    Carp::confess unless ( $self->user_object );
    return $self->user_object->principal_object;
}
1;
