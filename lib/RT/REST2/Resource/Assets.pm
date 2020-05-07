package RT::Extension::REST2::Resource::Assets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/assets/?$},
        block => sub { { collection_class => 'RT::Assets' } },
    )
}

__PACKAGE__->meta->make_immutable;

1;
