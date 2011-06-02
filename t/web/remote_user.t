use strict;
use warnings;
use RT;
use RT::Test tests => 9;

RT->Config->Set( DevelMode => 0 );
RT->Config->Set( WebExternalAuth => 1 );

my ( $url, $m ) = RT::Test->started_ok( basic_auth => 1 );
$m->get($url);
is($m->status, 401, "Initial request wuth no creds gets 401");

my $authority = URI->new($url)->authority;

$m->credentials(
    $authority,
    "restricted area",
    root => "wrong",
);
$m->get($url);
is($m->status, 401, "Request with wrong creds gets 401");

$m->credentials(
    $authority,
    "restricted area",
    root => "password",
);
$m->get($url);
is($m->status, 200, "Request with right creds gets 200");

$m->content_like(
    qr{<span class="current-user">\Qroot\E</span>}i,
    "Has user on the page"
);
$m->content_unlike(qr/Logout/i, "Has no logout button, no WebFallbackToInternalAuth");

$m->credentials(
    $authority,
    "restricted area",
    undef, undef
);
$m->get($url);
is($m->status, 401, "Subsequent requests without credentials aren't still logged in");


# Put the credentials back for the warnings check at the end
$m->credentials(
    $authority,
    "restricted area",
    root => "password",
);
