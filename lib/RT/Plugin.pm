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

use strict;
use warnings;

package RT::Plugin;
use File::ShareDir;

=head1 NAME

RT::Plugin

=head1 METHODS

=head2 new

Instantiate a new L<RT::Plugin> object. Takes a paramhash. currently the only key
it cares about is 'name', the name of this plugin.

=cut

sub new {
    my $class = shift;
    my $args ={@_};
    my $self = bless $args, $class;
    return $self;
}


=head2 Name

Returns a human-readable name for this plugin.

=cut

sub Name { 
    my $self = shift;
    return $self->{name};
}

=head2 Version

Returns the extension version.

=cut

sub Version {
    my $self = shift;
    no strict 'refs';
    return ${$self->Name . '::VERSION'};
}

=head2 Path

Takes a name of sub directory and returns its full path, for example:

    my $plugin_etc_dir = $plugin->Path('etc');

See also L</ComponentRoot>, L</StaticDir>, L</PoDir> and other shortcut methods.

=cut

sub Path {
    my $self   = shift;
    my $subdir = shift;
    my $res = $self->_BasePath;
    $res .= "/$subdir" if defined $subdir && length $subdir;
    return $res;
}

sub _BasePath {
    my $self = shift;
    my $base = $self->{'name'};
    $base =~ s/::/-/g;
    my $local_base = $RT::LocalPluginPath."/".$base;
    my $base_base = $RT::PluginPath."/".$base;

    return -d $local_base ? $local_base : $base_base;
}

=head2 ComponentRoot

Returns the directory this plugin has installed its L<HTML::Mason> templates into

=cut

sub ComponentRoot { return $_[0]->Path('html') }

=head2 StaticDir

Returns the directory this plugin has installed its static files into

=cut

sub StaticDir { return $_[0]->Path('static') }

=head2 PoDir

Returns the directory this plugin has installed its message catalogs into.

=cut

sub PoDir { return $_[0]->Path('po') }

RT::Base->_ImportOverlays();

1;
