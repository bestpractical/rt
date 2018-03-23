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

package RT::Shredder::Plugin;

use strict;
use warnings FATAL => 'all';
use File::Spec ();

=head1 NAME

RT::Shredder::Plugin - interface to access shredder plugins

=head1 SYNOPSIS

  use RT::Shredder::Plugin;

  # get list of the plugins
  my %plugins = RT::Shredder::Plugin->List;

  # load plugin by name
  my $plugin = RT::Shredder::Plugin->new;
  my( $status, $msg ) = $plugin->LoadByName( 'Tickets' );
  unless( $status ) {
      print STDERR "Couldn't load plugin 'Tickets': $msg\n";
      exit(1);
  }

  # load plugin by preformatted string
  my $plugin = RT::Shredder::Plugin->new;
  my( $status, $msg ) = $plugin->LoadByString( 'Tickets=status,deleted' );
  unless( $status ) {
      print STDERR "Couldn't load plugin: $msg\n";
      exit(1);
  }

=head1 METHODS

=head2 new

Object constructor, returns new object. Takes optional hash
as arguments, it's not required and this class doesn't use it,
but plugins could define some arguments and can handle them
after your've load it.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->_Init( @_ );
    return $self;
}

sub _Init
{
    my $self = shift;
    my %args = ( @_ );
    $self->{'opt'} = \%args;
    return;
}

=head2 List

Returns hash with names of the available plugins as keys and path to
library files as values. Method has no arguments. Can be used as class
method too.

Takes optional argument C<type> and leaves in the result hash only
plugins of that type.

=cut

sub List
{
    my $self = shift;
    my $type = shift;

    my @files;
    foreach my $root( @INC ) {
        my $mask = File::Spec->catfile( $root, qw(RT Shredder Plugin *.pm) );
        push @files, glob $mask;
    }

    my %res;
    for my $f (reverse @files) {
        $res{$1} = $f if $f =~ /([^\\\/]+)\.pm$/;
    }

    return %res unless $type;

    delete $res{'Base'};
    foreach my $name( keys %res ) {
        my $class = join '::', qw(RT Shredder Plugin), $name;
        unless( $class->require ) {
            delete $res{ $name };
            next;
        }
        next if lc $class->Type eq lc $type;
        delete $res{ $name };
    }

    return %res;
}

=head2 LoadByName

Takes name of the plugin as first argument, loads plugin,
creates new plugin object and reblesses self into plugin
if all steps were successfuly finished, then you don't need to
create new object for the plugin.

Other arguments are sent to the constructor of the plugin
(method new.)

Returns C<$status> and C<$message>. On errors status
is C<false> value.

In scalar context, returns $status only.

=cut

sub LoadByName
{
    my $self = shift;
    my $name = shift or return (0, "Name not specified");
    $name =~ /^\w+(::\w+)*$/ or return (0, "Invalid plugin name");

    my $plugin = "RT::Shredder::Plugin::$name";
    $plugin->require or return( 0, "Failed to load $plugin" );
    return wantarray ? ( 0, "Plugin '$plugin' has no method new") : 0 unless $plugin->can('new');

    my $obj = eval { $plugin->new( @_ ) };
    return wantarray ? ( 0, $@ ) : 0 if $@;
    return wantarray ? ( 0, 'constructor returned empty object' ) : 0 unless $obj;

    $self->Rebless( $obj );
    return wantarray ? ( 1, "successfuly load plugin" ) : 1;
}

=head2 LoadByString

Takes formatted string as first argument and which is used to
load plugin. The format of the string is

  <plugin name>[=<arg>,<val>[;<arg>,<val>]...]

exactly like in the L<rt-shredder> script. All other
arguments are sent to the plugins constructor.

Method does the same things as C<LoadByName>, but also
checks if the plugin supports arguments and values are correct,
so you can C<Run> specified plugin immediatly.

Returns list with C<$status> and C<$message>. On errors status
is C<false>.

=cut

sub LoadByString
{
    my $self = shift;
    my ($plugin, $args) = split /=/, ( shift || '' ), 2;

    my ($status, $msg) = $self->LoadByName( $plugin, @_ );
    return( $status, $msg ) unless $status;

    my %args;
    foreach( split /\s*;\s*/, ( $args || '' ) ) {
        my( $k,$v ) = split /\s*,\s*/, ( $_ || '' ), 2;
        unless( $args{$k} ) {
            $args{$k} = $v;
            next;
        }

        $args{$k} = [ $args{$k} ] unless UNIVERSAL::isa( $args{ $k }, 'ARRAY');
        push @{ $args{$k} }, $v;
    }

    ($status, $msg) = $self->HasSupportForArgs( keys %args );
    return( $status, $msg ) unless $status;

    ($status, $msg) = $self->TestArgs( %args );
    return( $status, $msg ) unless $status;

    return( 1, "successfuly load plugin" );
}

=head2 Rebless

Instance method that takes one object as argument and rebless
the current object into into class of the argument and copy data
of the former. Returns nothing.

Method is used by C<Load*> methods to automaticaly rebless
C<RT::Shredder::Plugin> object into class of the loaded
plugin.

=cut

sub Rebless
{
    my( $self, $obj ) = @_;
    bless( $self, ref $obj );
    %{$self} = %{$obj};
    return;
}

1;
