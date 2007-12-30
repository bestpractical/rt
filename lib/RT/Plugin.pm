use warnings;
use strict;

package RT::Plugin;
use File::ShareDir;

=head1 NAME

RT::Plugin

=head1 METHODS

=head2 new

Instantiate a new RT::Plugin object. Takes a paramhash. currently the only key it cares about is 'name', the name of this plugin.

=cut

sub new {
    my $class = shift;
    my $args ={@_};
    my $self = bless $args, $class;
    return $self;
}


=head2 name

Returns a human-readable name for this plugin.

=cut

sub name { 
    my $self = shift;
    return $self->{name};
}

sub _BasePath {
    my $self = shift;
    my $base = $self->{'name'};
    $base =~ s/::/-/g;

    return $RT::LocalPluginPath."/".$base;

}

=head2 ComponentRoot

Returns the directory this plugin has installed its HTML::Mason templates into

=cut

sub ComponentRoot {
    my $self = shift;

    return $self->_BasePath."/html";
}

=head2 PoDir

Returns the directory this plugin has installed its message catalogs into.

=cut

sub PoDir {
    my $self = shift;
    return $self->_BasePath."/po";

}

1;
