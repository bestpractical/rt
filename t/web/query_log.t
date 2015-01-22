use strict;
use warnings;

use RT::Test tests => 9;

RT->Config->Set(StatementLog => 1);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $root = RT::User->new($RT::SystemUser);
$root->LoadByEmail('root@localhost');

$m->get_ok("/Admin/Tools/Queries.html");
$m->text_contains("/index.html", "we include info about a page we hit while logging in");
$m->text_contains("Stack:", "stack traces");
$m->text_like(qr{/autohandler:\d+}, "stack trace includes mason components");
$m->text_contains("SELECT * FROM Principals WHERE id = '".$root->id."'", "we interpolate bind params");
