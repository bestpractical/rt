package RT::REST2::Resource::Role::RequestBodyIsJSON;
use strict;
use warnings;

use MooseX::Role::Parameterized;
use namespace::autoclean;

use JSON ();
use RT::REST2::Util qw( error_as_json );
use Moose::Util::TypeConstraints qw( enum );

parameter 'type' => (
    isa     => enum([qw(ARRAY HASH)]),
    default => 'HASH',
);

role {
    my $P = shift;

    around 'malformed_request' => sub {
        my $orig = shift;
        my $self = shift;
        my $malformed = $self->$orig(@_);
        return $malformed if $malformed;

        my $request = $self->request;
        return 0 unless $request->method =~ /^(PUT|POST)$/;
        return 0 unless $request->header('Content-Type') =~ /^application\/json/;

        my $json = eval {
            JSON::from_json($request->content)
        };
        if ($@ or not $json) {
            my $error = $@;
               $error =~ s/ at \S+? line \d+\.?$//;
            error_as_json($self->response, undef, "JSON parse error: $error");
            return 1;
        }
        elsif (ref $json ne $P->type) {
            error_as_json($self->response, undef, "JSON object must be a ", $P->type);
            return 1;
        } else {
            return 0;
        }
    };
};

1;
