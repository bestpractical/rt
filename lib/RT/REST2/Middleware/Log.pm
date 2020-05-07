package RT::Extension::REST2::Middleware::Log;

use strict;
use warnings;

use base 'Plack::Middleware';

sub call {
    my ( $self, $env ) = @_;

    # XXX TODO: logging of SQL queries in RT's framework for doing so
    $env->{'psgix.logger'} = sub {
        my $what = shift;
        RT->Logger->log(%$what);
    };

    return $self->app->($env);
}

1;
