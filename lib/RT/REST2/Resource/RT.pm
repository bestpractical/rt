package RT::REST2::Resource::RT;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/rt?$},
    );
}

sub charsets_provided      { [ 'utf-8' ] }
sub default_charset        {   'utf-8'   }
sub allowed_methods        { ['GET'] }

sub content_types_provided { [{ 'application/json' => 'to_json' }] }

sub to_json {
    my $self = shift;
    return JSON::to_json({
        Version => $RT::VERSION,
        Plugins => [ RT->Config->Get('Plugins') ],
    }, { pretty => 1 });
}
__PACKAGE__->meta->make_immutable;

1;

