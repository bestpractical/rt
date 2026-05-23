use strict;
use warnings;

use RT::Test tests => undef, nodb => 1;
use RT::Interface::Web::Handler;

my $forwarded_env = {
    REQUEST_METHOD        => 'GET',
    SCRIPT_NAME           => '',
    PATH_INFO             => '/',
    SERVER_NAME           => 'localhost',
    SERVER_PORT           => 8080,
    HTTP_HOST             => 'rt.example.com',
    REMOTE_ADDR           => '127.0.0.1',
    'psgi.url_scheme'     => 'http',
    HTTP_X_FORWARDED_PROTO => 'https',
    HTTP_X_FORWARDED_HOST  => 'rt.example.com',
    HTTP_X_FORWARDED_FOR   => '203.0.113.42',
};

my $recorded_env;
my $recorder = sub {
    $recorded_env = shift;
    return [ 200, [], [] ];
};

diag '$WebReverseProxy off: X-Forwarded-* headers are stripped';
RT->Config->Set( WebReverseProxy => 0 );
my $stripped = RT::Interface::Web::Handler->ReverseProxyWrap($recorder);
$stripped->( { %$forwarded_env } );
ok( !exists $recorded_env->{HTTP_X_FORWARDED_PROTO},  'X-Forwarded-Proto stripped' );
ok( !exists $recorded_env->{HTTP_X_FORWARDED_HOST},   'X-Forwarded-Host stripped' );
ok( !exists $recorded_env->{HTTP_X_FORWARDED_FOR},    'X-Forwarded-For stripped' );
is( $recorded_env->{'psgi.url_scheme'}, 'http',           'psgi.url_scheme unchanged' );
is( $recorded_env->{HTTP_HOST},         'rt.example.com', 'HTTP_HOST unchanged' );
is( $recorded_env->{SERVER_PORT},       8080,             'SERVER_PORT unchanged' );
is( $recorded_env->{REMOTE_ADDR},       '127.0.0.1',      'REMOTE_ADDR unchanged' );

diag '$WebReverseProxy on: X-Forwarded-* headers rewrite the env';
RT->Config->Set( WebReverseProxy => 1 );
my $proxied = RT::Interface::Web::Handler->ReverseProxyWrap($recorder);
$proxied->( { %$forwarded_env } );
is( $recorded_env->{'psgi.url_scheme'}, 'https',          'psgi.url_scheme rewritten from X-Forwarded-Proto' );
is( $recorded_env->{HTTP_HOST},         'rt.example.com', 'HTTP_HOST rewritten from X-Forwarded-Host' );
is( $recorded_env->{SERVER_PORT},       443,              'SERVER_PORT inferred from https scheme' );
is( $recorded_env->{REMOTE_ADDR},       '203.0.113.42',   'REMOTE_ADDR rewritten from X-Forwarded-For' );

diag '$WebReverseProxy on: X-Forwarded-Host with explicit port';
$proxied->(
    {
        %$forwarded_env,
        HTTP_X_FORWARDED_HOST => 'rt.example.com:8443',
    }
);
is( $recorded_env->{HTTP_HOST},   'rt.example.com:8443', 'HTTP_HOST preserves :port' );
is( $recorded_env->{SERVER_PORT}, 8443,                  'SERVER_PORT picks up nonstandard port' );

diag '$WebReverseProxy on: X-Forwarded-Port carries a nonstandard port';
$proxied->(
    {
        %$forwarded_env,
        HTTP_X_FORWARDED_HOST => 'rt.example.com',
        HTTP_X_FORWARDED_PORT => 8443,
    }
);
is( $recorded_env->{HTTP_HOST},   'rt.example.com:8443', 'HTTP_HOST gets :port appended from X-Forwarded-Port' );
is( $recorded_env->{SERVER_PORT}, 8443,                  'SERVER_PORT comes from X-Forwarded-Port' );

diag '$WebReverseProxy on: X-Forwarded-For with multiple hops keeps the last value';
$proxied->(
    {
        %$forwarded_env,
        HTTP_X_FORWARDED_FOR => '10.0.0.1, 10.0.0.2, 203.0.113.42',
    }
);
is( $recorded_env->{REMOTE_ADDR}, '203.0.113.42', 'REMOTE_ADDR is last X-Forwarded-For value' );

done_testing;
