package RT::REST2::Resource::Group;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid);

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable'
        => { -alias => { serialize => '_default_serialize' } },
    'RT::REST2::Resource::Record::DeletableByDisabling',
        => { -alias => { delete_resource => '_delete_resource' } },
    'RT::REST2::Resource::Record::Writable',
        => { -alias => { create_record => '_create_record' } },
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/?$},
        block => sub { { record_class => 'RT::Group' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/(\d+)/?$},
        block => sub { { record_class => 'RT::Group', record_id => shift->pos(1) } },
    )
}

sub serialize {
    my $self = shift;
    my $data = $self->_default_serialize(@_);

    $data->{Members} = [
        map { expand_uid($_->MemberObj->Object->UID) }
        @{ $self->record->MembersObj->ItemsArrayRef }
    ];

    $data->{Disabled} = $self->record->PrincipalObj->Disabled;

    return $data;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    push @$links, $self->_transaction_history_link;

    my $id = $self->record->id;
    push @$links,
      { ref  => 'members',
        _url => RT::REST2->base_uri . "/group/$id/members",
      };
    return $links;
}

sub create_record {
    my $self = shift;
    my $data = shift;

    return (\403, $self->record->loc("Permission Denied"))
        unless  $self->current_user->HasRight(
            Right   => "AdminGroup",
            Object  => RT->System,
        );

    return $self->_create_record($data);
}

sub delete_resource {
    my $self = shift;

    return (\403, $self->record->loc("Permission Denied"))
        unless $self->record->CurrentUserHasRight('AdminGroup');

    return $self->_delete_resource;
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('SeeGroup');
}

__PACKAGE__->meta->make_immutable;

1;

