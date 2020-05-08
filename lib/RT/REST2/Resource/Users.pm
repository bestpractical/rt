package RT::REST2::Resource::Users;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/users/?$},
        block => sub { { collection_class => 'RT::Users' } },
    ),
}

sub searchable_fields {
    my $self = shift;
    my $class = $self->collection->RecordClass;
    my @fields;
    if ($self->current_user->HasRight(
            Right   => "AdminUsers",
            Object  => RT->System,
        )) {
        @fields = grep {
            $class->_Accessible($_ => "public")
        } $class->ReadableAttributes;
    }
    else {
        @fields = split(/\s*\,\s*/, RT->Config->Get('UserSummaryExtraInfo'));
    }
    return @fields
}

sub forbidden {
    my $self = shift;

    return 0 if $self->current_user->Privileged;
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
