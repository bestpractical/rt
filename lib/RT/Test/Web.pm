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

package RT::Test::Web;

use strict;
use warnings;

use base qw(Test::WWW::Mechanize);

require RT::Test;
require Test::More;

sub get_ok {
    my $self = shift;
    my $url = shift;
    if ( $url =~ s!^/!! ) {
        $url = $self->rt_base_url . $url;
    }
    my $rv = $self->SUPER::get_ok($url, @_);
    Test::More::diag( "Couldn't get $url" ) unless $rv;
    return $rv;
}

sub rt_base_url {
    return $RT::Test::existing_server if $RT::Test::existing_server;
    return "http://localhost:" . RT->Config->Get('WebPort') . RT->Config->Get('WebPath') . "/";
}

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';

    my $url = $self->rt_base_url;

    $self->get($url);
    Test::More::diag( "error: status is ". $self->status )
        unless $self->status == 200;
    if ( $self->content =~ qr/Logout/i ) {
        $self->follow_link( text => 'Logout' );
    }

    $self->get($url . "?user=$user;pass=$pass");
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    unless ( $self->content =~ qr/Logout/i ) {
        Test::More::diag("error: page has no Logout");
        return 0;
    }
    return 1;
}

sub goto_ticket {
    my $self = shift;
    my $id   = shift;
    unless ( $id && int $id ) {
        Test::More::diag( "error: wrong id ". defined $id? $id : '(undef)' );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "/Ticket/Display.html?id=$id";
    $self->get($url);
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    return 1;
}

sub goto_create_ticket {
    my $self = shift;
    my $queue = shift;

    my $id;
    if ( ref $queue ) {
        $id = $queue->id;
    } elsif ( $queue =~ /^\d+$/ ) {
        $id = $queue;
    } else {
        die "not yet implemented";
    }

    $self->get('/');
    $self->form_name('CreateTicketInQueue');
    $self->select( 'Queue', $id );
    $self->submit;

    return 1;
}

sub get_warnings {
    my $self = shift;
    my $server_class = 'RT::Interface::Web::Standalone';

    my $url = $server_class->test_warning_path;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return unless $self->get_ok($url);

    my @warnings = $server_class->decode_warnings($self->content);
    return @warnings;
}

sub warning_like {
    my $self = shift;
    my $re   = shift;
    my $name = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @warnings = $self->get_warnings;
    if (@warnings == 0) {
        Test::More::fail("no warnings emitted; expected 1");
        return 0;
    }
    elsif (@warnings > 1) {
        Test::More::fail(scalar(@warnings) . " warnings emitted; expected 1");
        for (@warnings) {
            Test::More::diag("got warning: $_");
        }
        return 0;
    }

    return Test::More::like($warnings[0], $re, $name);
}

sub no_warnings_ok {
    my $self = shift;
    my $name = shift || "no warnings emitted";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @warnings = $self->get_warnings;

    Test::More::is(@warnings, 0, $name);
    for (@warnings) {
        Test::More::diag("got warning: $_");
    }

    return @warnings == 0 ? 1 : 0;
}

1;
