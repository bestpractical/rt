# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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

package RT::Plugin;
use File::ShareDir;
use Class::Accessor "antlers";
use Parse::CPAN::Meta;
use UNIVERSAL::require;

=head1 NAME

RT::Plugin

=head1 METHODS

=head2 new

Instantiate a new L<RT::Plugin> object. Takes a paramhash. currently the only key
it cares about is 'name', the name of this plugin.

=cut

use List::MoreUtils qw(first_index);

has _added_inc_path => (is => "rw", isa => "Str");
has Name => (is => "rw", isa => "Str");
has Enabled => (is => "rw", isa => "Bool");
has ConfigEnabled => (is => "rw", isa => "Bool");
has Description => (is => "rw", isa => "Str");
has BasePath => (is => "rw", isa => "Str");

sub new {
    my $class = shift;
    my $args ={@_};
    my $self = bless $args, $class;

    return $self;
}

# the @INC entry that plugins lib dirs should be pushed splice into.
# it should be the one after local lib
my $inc_anchor;
sub Enable {
    my ($self, $global) = @_;
    my $add = $self->Path("lib");
    $self->ConfigEnabled(1)
        if $global;
    unless (defined $inc_anchor) {
        my $anchor = first_index { Cwd::realpath($_) eq Cwd::realpath($RT::LocalLibPath) } @INC;
        $inc_anchor = ($anchor == -1 || $anchor == $#INC) # not found or last
            ? '' : Cwd::realpath($INC[$anchor+1]);
    }
    my $anchor_idx = first_index { Cwd::realpath($_) eq $inc_anchor } @INC;
    if ($anchor_idx >= 0 ) {
        splice(@INC, $anchor_idx, 0, $add);
    }
    else {
        push @INC, $add;
    }
    my $module = $self->Name;
    $module =~ s/-/::/g;
    $module->require;
    die $UNIVERSAL::require::ERROR if ($UNIVERSAL::require::ERROR);
    $self->Enabled(1);
    $self->_added_inc_path( $add );
}

sub DESTROY {
    my $self = shift;
    my $added = $self->_added_inc_path or return;
    my $inc_path = first_index { Cwd::realpath($_) eq $added } @INC;
    if ($inc_path >= 0 ) {
        splice(@INC, $inc_path, 1);
    }
}

=head2 Path

Takes a name of sub directory and returns its full path, for example:

    my $plugin_etc_dir = $plugin->Path('etc');

See also L</ComponentRoot>, L</PoDir> and other shortcut methods.

=cut

sub Path {
    my $self   = shift;
    my $subdir = shift;
    my $res = $self->BasePath || $self->BasePathFor($self->Name);
    $res .= "/$subdir" if defined $subdir && length $subdir;
    return $res;
}

=head2 $class->BasePathFor($name)

Takes a name of a given plugin and return its base path.

=cut

sub BasePathFor {
    my ($class, $name) = @_;

    $name =~ s/::/-/g;
    my $local_base = $RT::LocalPluginPath."/".$name;
    my $base_base = $RT::PluginPath."/".$name;

    return -d $local_base ? $local_base : $base_base;
}

=head2 AvailablePlugins($plugin_path)

=cut

sub AvailablePlugins {
    my ($class, $plugin_path) = @_;
    my @res;
    my @paths = $plugin_path ? ($plugin_path) : ($RT::LocalPluginPath, $RT::PluginPath);
    for my $abs_path (map { <$_/*> } @paths) {
        my ($dir, $name) = $abs_path =~ m|(.*)/([^/]+)$|;
        # ensure no cascading
        next if $class->BasePathFor($name) ne $abs_path;
        push @res, $class->ProbePlugin($name);
    }

    # XXX: look for collision and warn
    my %seen;
    return { map { $seen{$_->Name}++ ? () : ($_->Name => $_) } @res };
}

sub ProbePlugin {
    my ($class, $name) = @_;
    my $base_path = $class->BasePathFor($name);
    my $meta;
    if (-e "$base_path/META.yml") {
        ($meta) = Parse::CPAN::Meta::LoadFile( "$base_path/META.yml" ) or return;
    }
    else {
        $meta = { name => $name };
    }

    return $class->new(Name => $meta->{name},
                       Description => $meta->{abstract},
                       BasePath => $base_path);
}

=head2 ComponentRoot

Returns the directory this plugin has installed its L<HTML::Mason> templates into

=cut

sub ComponentRoot { return $_[0]->Path('html') }

=head2 PoDir

Returns the directory this plugin has installed its message catalogs into.

=cut

sub PoDir { return $_[0]->Path('po') }

RT::Base->_ImportOverlays();

1;
