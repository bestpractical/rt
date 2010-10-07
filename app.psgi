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
use warnings;
use strict;

use File::Basename;
eval {
    require (dirname(__FILE__) .'/bin/webmux.pl');
};
if ($@) {
    die "failed to load bin/webmux.pl: $@";
}

use HTML::Mason::PSGIHandler;
use RT::Interface::Web::Handler;
use CGI::Emulate::PSGI;
use Plack::Request;

use Encode qw(is_utf8 encode_utf8);

my $h = RT::Interface::Web::Handler::NewHandler('HTML::Mason::PSGIHandler');
my $handler = sub {
    my $env = shift;
    RT::ConnectToDatabase() unless RT->InstallMode;

    my $req = Plack::Request->new($env);

    unless ( $h->interp->comp_exists( $req->path_info ) ) {
        my $path = $req->path_info;
        $path .= '/' unless $path =~ m{/$};
        $path .= 'index.html';
        $env->{PATH_INFO} = $path
            if $h->interp->comp_exists( $path );
    }

    my $ret;
    {
        # XXX: until we get rid of all $ENV stuff.
        local %ENV = (%ENV, CGI::Emulate::PSGI->emulate_environment($env));

        $ret = $h->handle_psgi($env);
    }
    $RT::Logger->crit($@) if $@ && $RT::Logger;
    warn $@ if $@ && !$RT::Logger;
    RT::Interface::Web::Handler->CleanupRequest();
    if ($ret->[2] ) {
        # XXX: for now.  the out_method for mason can be more careful
        # and perhaps even streamy.  this should also check for
        # explicit encoding in Content-Type header.
        for (@{$ret->[2]}) { 
            $_ = encode_utf8($_)
                if is_utf8($_);
        }
    }
    return $ret;
};
