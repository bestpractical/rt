# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

=head1 SYNOPSIS

  use RT::Squish::JS;
  my $squish = RT::Squish::JS->new();

=head1 DESCRIPTION

This module lets you create squished content of js files.

=head1 METHODS

=cut

use strict;
use warnings;

package RT::Squish::JS;
use base 'RT::Squish';

=head2 Squish

not only concatenate files, but also minify them

=cut

sub Squish {
    my $self    = shift;
    my $content = "";

    for my $file ( RT::Interface::Web->JSFiles ) {
        my $uri = $file =~ m{^/} ? $file : "/static/js/$file";
        my $res = RT::Interface::Web::Handler->GetStatic($uri);

        if ($res->is_success) {
            $content .= $res->decoded_content;
        } else {
            RT->Logger->error("Unable to fetch $uri for JS Squishing: " . $res->status_line);
            next;
        }
    }

    return $self->Filter($content);
}

sub Filter {
    my $self    = shift;
    my $content = shift;

    my $minified;
    my $jsmin = RT->Config->Get('JSMinPath');
    if ( $jsmin && -x $jsmin ) {
        my $input = $content;
        my ( $output, $error );

        # If we're running under fastcgi, STDOUT and STDERR are tied
        # filehandles, which cause IPC::Run3 to flip out.  Construct
        # temporary, not-tied replacements for it to see instead.
        my $stdout = IO::Handle->new;
        $stdout->fdopen( 1, 'w' );
        local *STDOUT = $stdout;
        my $stderr = IO::Handle->new;
        $stderr->fdopen( 2, 'w' );
        local *STDERR = $stderr;

        local $SIG{'CHLD'} = 'DEFAULT';
        require IPC::Run3;
        IPC::Run3::run3( [$jsmin], \$input, \$output, \$error );
        if ( $? >> 8 ) {
            $RT::Logger->warning("failed to jsmin: $error ");
        }
        else {
            $content  = $output;
            $minified = 1;
        }
    }

    return $content;
}

1;

