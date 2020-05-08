package RT::REST2::Resource::TicketsBulk;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' =>
  { type => 'ARRAY' };

use RT::REST2::Util qw(expand_uid);
use RT::REST2::Resource::Ticket;
use JSON ();

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new( regex => qr{^/tickets/bulk/?$} );
}

sub post_is_create    { 1 }
sub create_path       { '/tickets/bulk' }
sub charsets_provided { [ 'utf-8' ] }
sub default_charset   { 'utf-8' }
sub allowed_methods   { [ 'PUT', 'POST' ] }

sub content_types_provided { [ { 'application/json' => sub {} } ] }
sub content_types_accepted { [ { 'application/json' => 'from_json' } ] }

sub from_json {
    my $self   = shift;
    my $params = JSON::decode_json( $self->request->content );

    my $method = $self->request->method;
    my @results;
    if ( $method eq 'PUT' ) {
        for my $param ( @$params ) {
            my $id = delete $param->{id};
            if ( $id && $id =~ /^\d+$/ ) {
                my $resource = RT::REST2::Resource::Ticket->new(
                    request      => $self->request,
                    response     => $self->response,
                    record_class => 'RT::Ticket',
                    record_id    => $id,
                );
                if ( $resource->resource_exists ) {
                    push @results, [ $id, $resource->update_record( $param ) ];
                    next;
                }
            }
            push @results, [ $id, 'Resource does not exist' ];
        }
    }
    else {
        for my $param ( @$params ) {
            my $resource = RT::REST2::Resource::Ticket->new(
                request      => $self->request,
                response     => $self->response,
                record_class => 'RT::Ticket',
            );
            my ( $ok, $msg ) = $resource->create_record( $param );
            if ( ref( $ok ) || !$ok ) {
                push @results, { message => $msg || "Create failed for unknown reason" };
            }
            else {
                push @results, expand_uid( $resource->record->UID );
            }
        }
    }

    $self->response->body( JSON::encode_json( \@results ) );
    return;
}

__PACKAGE__->meta->make_immutable;

1;
