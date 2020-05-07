package RT::Extension::REST2::Resource::Groups;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/groups/?$},
        block => sub { { collection_class => 'RT::Groups' } },
    ),
}

__PACKAGE__->meta->make_immutable;

1;

