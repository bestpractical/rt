package RT::Extension::REST2::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::ProcessPOSTasGET';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/tickets/?$},
        block => sub { { collection_class => 'RT::Tickets' } },
    )
}

use Encode qw( decode_utf8 );
use RT::Extension::REST2::Util qw( error_as_json );
use RT::Search::Simple;

has 'query' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    lazy_build  => 1,
);

sub _build_query {
    my $self  = shift;
    my $query = decode_utf8($self->request->param('query') || "");

    if ($self->request->param('simple') and $query) {
        # XXX TODO: Note that "normal" ModifyQuery callback isn't invoked
        # XXX TODO: Special-casing of "#NNN" isn't used
        my $search = RT::Search::Simple->new(
            Argument    => $query,
            TicketsObj  => $self->collection,
        );
        $query = $search->QueryToSQL;
    }
    return $query;
}

sub allowed_methods {
    [ 'GET', 'HEAD', 'POST' ]
}

sub limit_collection {
    my $self = shift;
    my ($ok, $msg) = $self->collection->FromSQL( $self->query );
    return error_as_json( $self->response, 0, $msg ) unless $ok;

    my @orderby_cols;
    my @orders = $self->request->param('order');
    foreach my $orderby ($self->request->param('orderby')) {
        $orderby = decode_utf8($orderby);
        my $order = shift @orders || 'ASC';
        $order = uc(decode_utf8($order));
        $order = 'ASC' unless $order eq 'DESC';
        push @orderby_cols, {FIELD => $orderby, ORDER => $order};
    }
    $self->collection->OrderByCols(@orderby_cols)
        if @orderby_cols;

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
