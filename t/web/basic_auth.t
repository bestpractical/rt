use strict;
use warnings;
use RT;
use RT::Test tests => 9;

RT->Config->Set( DevelMode => 0 );
RT->Config->Set( WebRemoteUserAuth => 1 );

my ( $url, $m ) = RT::Test->started_ok( basic_auth => 1 );

# This tests the plack middleware, not RT
$m->get($url);
is($m->status, 401, "Initial request with no creds gets 401");

# This tests the plack middleware, not RT
$m->get($url, $m->auth_header( root => "wrong" ));
is($m->status, 401, "Request with wrong creds gets 401");

$m->get($url, $m->auth_header( root => "password" ));
is($m->status, 200, "Request with right creds gets 200");

$m->content_like(
    qr{<span class="current-user">\Qroot\E</span>}i,
    "Has user on the page"
);
$m->content_unlike(qr/Logout/i, "Has no logout button, no WebFallbackToRTLogin");

# Again, testing the plack middleware
$m->get($url);
is($m->status, 401, "Subsequent requests without credentials aren't still logged in");


# Put the credentials back for the warnings check at the end
$m->auth( root => "password" );
