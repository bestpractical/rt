package RT::Extension::REST2::Resource::Catalog;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with (
    'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::Extension::REST2::Resource::Record::DeletableByDisabling',
    'RT::Extension::REST2::Resource::Record::Writable',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/catalog/?$},
        block => sub { { record_class => 'RT::Catalog' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/catalog/(\d+)/?$},
        block => sub { { record_class => 'RT::Catalog', record_id => shift->pos(1) } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/catalog/([^/]+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $catalog = RT::Catalog->new($req->env->{"rt.current_user"});
            $catalog->Load($match->pos(1));
            return { record => $catalog };
        },
    ),
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    my $catalog = $self->record;

    push @$links, {
        ref  => 'create',
        type => 'asset',
        _url => RT::Extension::REST2->base_uri . '/asset?Catalog=' . $catalog->Id,
    } if $catalog->CurrentUserHasRight('CreateAsset');

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;
