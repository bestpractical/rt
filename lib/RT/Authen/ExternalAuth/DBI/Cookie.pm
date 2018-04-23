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

package RT::Authen::ExternalAuth::DBI::Cookie;

use CGI::Cookie;

use warnings;
use strict;

=head1 NAME

RT::Authen::ExternalAuth::DBI::Cookie - Database-backed, cookie SSO source for RT authentication

=head1 DESCRIPTION

Provides the Cookie implementation for L<RT::Authen::ExternalAuth>.

=head1 SYNOPSIS

    Set($ExternalSettings, {
        # An example SSO cookie service
        'My_SSO_Cookie'  => {
            'type'            =>  'cookie',
            'name'            =>  'loginCookieValue',
            'u_table'         =>  'users',
            'u_field'         =>  'username',
            'u_match_key'     =>  'userID',
            'c_table'         =>  'login_cookie',
            'c_field'         =>  'loginCookieValue',
            'c_match_key'     =>  'loginCookieUserID',
            'db_service_name' =>  'My_MySQL'
        },
        'My_MySQL' => {
            ...
        },
    } );

=head1 CONFIGURATION

Cookie-specific options are described here. Shared options
are described in L<RT::Authen::ExternalAuth::DBI>.

The example in the L</SYNOPSIS> lists all available options
and they are described below.

=over 4

=item name

The name of the cookie to be used.

=item u_table

The users table.

=item u_field

The username field in the users table.

=item u_match_key

The field in the users table that uniquely identifies a user
and also exists in the cookies table. See c_match_key below.

=item c_table

The cookies table.

=item c_field

The field that stores cookie values.

=item c_match_key

The field in the cookies table that uniquely identifies a user
and also exists in the users table. See u_match_key above.

=item db_service_name

The DB service in this configuration to use to lookup the cookie
information. See L<RT::Authen::ExternalAuth::DBI>.

=back

=cut

# {{{ sub GetCookieVal
sub GetCookieVal {

    # The name of the cookie
    my $cookie_name = shift;
    my $cookie_value;

    # Pull in all cookies from browser within our cookie domain
    my %cookies = CGI::Cookie->fetch();

    # If the cookie is set, get the value, if it's not set, get out now!
    if (defined $cookies{$cookie_name}) {
      $cookie_value = $cookies{$cookie_name}->value;
      $RT::Logger->debug(  "Cookie Found",
                           ":: $cookie_name");
    } else {
        $RT::Logger->debug( "Cookie Not Found");
    }

    return $cookie_value;
}

# }}}

RT::Base->_ImportOverlays();

1;
