package RT::REST2::Resource::CustomRole;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
     'RT::REST2::Resource::Record::Hypermedia';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customrole/?$},
        block => sub { { record_class => 'RT::CustomRole' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customrole/(\d+)/?$},
        block => sub { { record_class => 'RT::CustomRole', record_id => shift->pos(1) } },
    )
}

__PACKAGE__->meta->make_immutable;

1;

