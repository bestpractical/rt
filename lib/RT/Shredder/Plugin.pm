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
  my $plugin = new RT::Shredder::Plugin;
  my( $status, $msg ) = $plugin->LoadByString( 'Tickets' );
  unless( $status ) {
      print STDERR "Couldn't load plugin 'Tickets': $msg\n";
      exit(1);
  }

  # load plugin by preformatted string
  my $plugin = new RT::Shredder::Plugin;
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
}

=head2 List

Returns hash with names of the available plugins as keys and path to
library files as values. Method has no arguments. Can be used as class
method too.

=cut

sub List
{
    my $self = shift;
    my @files;
    foreach my $root( @INC ) {
        my $mask = File::Spec->catdir( $root, qw(RT Shredder Plugin *.pm) );
        push @files, glob $mask;
    }

    my %res = map { $_ =~ m/([^\\\/]+)\.pm$/; $1 => $_ } reverse @files;

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

=cut

sub LoadByName
{
    my $self = shift;
    my $name = shift or return (0, "Name not specified");

    local $@;
    my $plugin = "RT::Shredder::Plugin::$name";
    eval "require $plugin" or return( 0, $@ );
    return( 0, "Plugin '$plugin' has no method new") unless $plugin->can('new');

    my $obj = eval { $plugin->new( @_ ) };
    return( 0, $@ ) if $@;
    return( 0, 'constructor returned empty object' ) unless $obj;

    $self->Rebless( $obj );
    return( 1, "successfuly load plugin" );
}

=head2 LoadByString

Takes formatted string as first argument and which is used to
load plugin. The format of the string is

  <plugin name>[=<arg>,<val>[;<arg>,<val>]...]

exactly like in the L<rtx-shredder> script. All other
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
