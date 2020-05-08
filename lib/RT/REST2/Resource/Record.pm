package RT::REST2::Resource::Record;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';

use Web::Machine::Util qw( create_date );
use RT::REST2::Util qw( record_type );

has 'record_class' => (
    is  => 'ro',
    isa => 'ClassName',
);

has 'record_id' => (
    is  => 'ro',
    isa => 'Int',
);

has 'record' => (
    is          => 'ro',
    isa         => 'RT::Record',
    required    => 1,
    lazy_build  => 1,
);

sub _build_record {
    my $self = shift;
    my $class = $self->record_class;
    my $id = $self->record_id;

    $class->require;

    my $record = $class->new( $self->current_user );
    $record->Load($id) if $id;
    return $record;
}

sub base_uri {
    my $self = shift;
    my $base = RT::REST2->base_uri;
    my $type = lc record_type($self);
    return join '/', $base, $type;
}

sub resource_exists {
    $_[0]->record->id
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;

    my $can_see = $self->record->can("CurrentUserCanSee");
    return 1 if $can_see and not $self->record->$can_see();
    return 0;
}

sub last_modified {
    my $self = shift;
    return unless $self->record->_Accessible("LastUpdated" => "read");
    my $updated = $self->record->LastUpdatedObj->RFC2616
        or return;
    return create_date($updated);
}

sub allowed_methods {
    my $self = shift;
    my @ok;
    push @ok, 'GET', 'HEAD' if $self->DOES("RT::REST2::Resource::Record::Readable");
    push @ok, 'DELETE'      if $self->DOES("RT::REST2::Resource::Record::Deletable");
    push @ok, 'PUT', 'POST' if $self->DOES("RT::REST2::Resource::Record::Writable");
    return \@ok;
}

sub finish_request {
    my $self = shift;
    # Ensure the record object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_record;
    return $self->SUPER::finish_request(@_);
}

__PACKAGE__->meta->make_immutable;

1;
