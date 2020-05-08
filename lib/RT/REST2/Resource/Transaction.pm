package RT::REST2::Resource::Transaction;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
     'RT::REST2::Resource::Record::Hypermedia'
         => { -alias => { hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transaction/?$},
        block => sub { { record_class => 'RT::Transaction' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transaction/(\d+)/?$},
        block => sub { { record_class => 'RT::Transaction', record_id => shift->pos(1) } },
    )
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);

    my $attachments = $self->record->Attachments;
    while (my $attachment = $attachments->Next) {
        my $id = $attachment->Id;
        push @$links, {
            ref  => 'attachment',
            _url => RT::REST2->base_uri . "/attachment/$id",
        };
    }

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

