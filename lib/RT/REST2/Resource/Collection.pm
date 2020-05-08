package RT::Extension::REST2::Resource::Collection;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource';

use Scalar::Util qw( blessed );
use Web::Machine::FSM::States qw( is_status_code );
use Module::Runtime qw( require_module );
use RT::Extension::REST2::Util qw( serialize_record expand_uid format_datetime );
use POSIX qw( ceil );

has 'collection_class' => (
    is  => 'ro',
    isa => 'ClassName',
);

has 'collection' => (
    is          => 'ro',
    isa         => 'RT::SearchBuilder',
    required    => 1,
    lazy_build  => 1,
);

sub _build_collection {
    my $self = shift;
    my $collection = $self->collection_class->new( $self->current_user );
    return $collection;
}

sub setup_paging {
    my $self = shift;
    my $per_page = $self->request->param('per_page') || 20;
    if    ( $per_page !~ /^\d+$/ ) { $per_page = 20 }
    elsif ( $per_page == 0 )       { $per_page = 20 }
    elsif ( $per_page > 100 )      { $per_page = 100 }
    $self->collection->RowsPerPage($per_page);

    my $page = $self->request->param('page') || 1;
    if    ( $page !~ /^\d+$/ ) { $page = 1 }
    elsif ( $page == 0 )       { $page = 1 }
    $self->collection->GotoPage($page - 1);
}

sub limit_collection {
    my $self        = shift;
    my $collection  = $self->collection;
    $collection->{'find_disabled_rows'} = 1
        if $self->request->param('find_disabled_rows');

    return 1;
}

sub search {
    my $self = shift;
    $self->setup_paging;
    return $self->limit_collection;
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;
    my @fields = defined $self->request->param('fields') ? split(/,/, $self->request->param('fields')) : ();

    while (my $item = $collection->Next) {
        my $result = expand_uid( $item->UID );

        # Allow selection of desired fields
        if ($result) {
            for my $field (@fields) {
                my $field_result = $self->expand_field($item, $field);
                $result->{$field} = $field_result if defined $field_result;
            }
        }
        push @results, $result;
    }

    my %results = (
        count       => scalar(@results)         + 0,
        total       => $collection->CountAll    + 0,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    );

    my $uri = $self->request->uri;
    my @query_form = $uri->query_form;
    # find page and if it is set, delete it and its value.
    for my $i (0..$#query_form) {
        if ($query_form[$i] eq 'page') {
            delete @query_form[$i, $i + 1];
            last;
        }
    }

    $results{pages} = ceil($results{total} / $results{per_page});
    if ($results{page} < $results{pages}) {
        my $page = $results{page} + 1;
        $uri->query_form( @query_form, page => $results{page} + 1 );
        $results{next_page} = $uri->as_string;
    };
    if ($results{page} > 1) {
        # If we're beyond the last page, set prev_page as the last page
        # available, otherwise, the previous page.
        $uri->query_form( @query_form, page => ($results{page} > $results{pages} ? $results{pages} : $results{page} - 1) );
        $results{prev_page} = $uri->as_string;
    };

    return \%results;
}

# XXX TODO: Bulk update via DELETE/PUT on a collection resource?

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    my $status = $self->search;
    return $status if is_status_code($status);
    return \400 unless $status;
    return JSON::to_json($self->serialize, { pretty => 1 });
}

sub finish_request {
    my $self = shift;
    # Ensure the collection object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_collection;
    return $self->SUPER::finish_request(@_);
}

__PACKAGE__->meta->make_immutable;

1;
