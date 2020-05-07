package RT::Extension::REST2::Resource::Attachment;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::Readable',
     'RT::Extension::REST2::Resource::Record::Hypermedia';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachment/?$},
        block => sub { { record_class => 'RT::Attachment' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachment/(\d+)/?$},
        block => sub { { record_class => 'RT::Attachment', record_id => shift->pos(1) } },
    )
}

__PACKAGE__->meta->make_immutable;

1;

