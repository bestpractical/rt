package RT::Extension::REST2::Middleware::ErrorAsJSON;

use strict;
use warnings;

use base 'Plack::Middleware';

use Plack::Util;
use HTTP::Status qw(is_error status_message);
use RT::Extension::REST2::Util 'error_as_json';

sub call {
    my ( $self, $env ) = @_;
    my $res = $self->app->($env);
    return Plack::Util::response_cb($res, sub {
        my $psgi_res = shift;
        my $status_code = $psgi_res->[0];
        my $headers = $psgi_res->[1];
        my $content_type = Plack::Util::header_get($headers, 'content-type');
        my $is_json = $content_type && $content_type =~ m/json/i;
        if ( is_error($status_code) && !$is_json ) {
            my $plack_res = Plack::Response->new($status_code, $headers);
            error_as_json($plack_res, undef, status_message($status_code));
            @$psgi_res = @{ $plack_res->finalize };
        }
        return;
    });
}

1;
