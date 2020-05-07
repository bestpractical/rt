package RT::Extension::REST2::Resource::Asset;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Record';
with (
    'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::Extension::REST2::Resource::Record::Deletable',
    'RT::Extension::REST2::Resource::Record::Writable'
        => { -alias => { create_record => '_create_record' } },
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/asset/?$},
        block => sub { { record_class => 'RT::Asset' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/asset/(\d+)/?$},
        block => sub { { record_class => 'RT::Asset', record_id => shift->pos(1) } },
    )
}

sub create_record {
    my $self = shift;
    my $data = shift;

    return (\400, "Invalid Catalog") if !$data->{Catalog};

    my $catalog = RT::Catalog->new($self->record->CurrentUser);
    $catalog->Load($data->{Catalog});

    return (\400, "Invalid Catalog") if !$catalog->Id;

    return (\403, $self->record->loc("Permission Denied", $catalog->Name))
        unless $catalog->CurrentUserHasRight('CreateAsset');

    return $self->_create_record($data);
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('ShowAsset');
}

sub lifecycle_hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $asset = $self->record;
    my @links;

    # lifecycle actions
    my $lifecycle = $asset->LifecycleObj;
    my $current = $asset->Status;

    for my $info ( $lifecycle->Actions($current) ) {
        my $next = $info->{'to'};
        next unless $lifecycle->IsTransition( $current => $next );

        my $check = $lifecycle->CheckRight( $current => $next );
        next unless $asset->CurrentUserHasRight($check);

        my $url = $self_link->{_url};

        push @links, {
            %$info,
            label => $self->current_user->loc($info->{'label'} || ucfirst($next)),
            ref   => 'lifecycle',
            _url  => $url,
        };
    }

    return @links;
}

sub hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $links = $self->_default_hypermedia_links(@_);
    my $asset = $self->record;

    push @$links, $self->_transaction_history_link;
    push @$links, $self->lifecycle_hypermedia_links;

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

