package RT::Extension::REST2::Resource::CustomRoles;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customroles/?$},
        block => sub { { collection_class => 'RT::CustomRoles' } },
    ),
}

__PACKAGE__->meta->make_immutable;

1;

