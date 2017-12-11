use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;

# Get a non-REST session
diag "Standard web session";
ok $m->login, 'logged in';
$m->content_contains("RT at a glance", "Get full UI content");

# Requesting a REST page should be fine, as we have a Referer
$m->post("$baseurl/REST/1.0/ticket/new", [
    format  => 'l',
]);
$m->content_like(qr{^id: ticket/new}m, "REST request with referrer");

# Removing the Referer header gets us an interstitial
$m->add_header(Referer => undef);
$m->post("$baseurl/REST/1.0/ticket/new", [
    format  => 'l',
    foo     => 'bar',
]);
$m->content_contains("Possible cross-site request forgery",
                 "REST request without referrer is blocked");

# But passing username and password lets us though
$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
    format  => 'l',
]);
$m->content_like(qr{^id: ticket/new}m, "REST request without referrer, but username/password supplied, is OK");

# And we can still access non-REST urls
$m->get("$baseurl");
$m->content_contains("RT at a glance", "Full UI is still available");


# Now go get a REST session
diag "REST session";
$m = RT::Test::Web->new;
$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
    format  => 'l',
]);
$m->content_like(qr{^id: ticket/new}m, "REST request to log in");

# Requesting that page again, with a username/password but no referrer,
# is fine
$m->add_header(Referer => undef);
$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
    format  => 'l',
]);
$m->content_like(qr{^id: ticket/new}m, "REST request with no referrer, but username/pass");

# And it's still fine without both referer and username and password,
# because REST is special-cased
$m->post("$baseurl/REST/1.0/ticket/new", [
    format  => 'l',
]);
$m->content_like(qr{^id: ticket/new}m, "REST request with no referrer or username/pass is special-cased for REST sessions");

# But the REST page can't request normal pages
$m->get("$baseurl");
$m->content_lacks("RT at a glance", "Full UI is denied for REST sessions");
$m->content_contains("This login session belongs to a REST client", "Tells you why");
$m->warning_like(qr/This login session belongs to a REST client/, "Logs a warning");

done_testing;

