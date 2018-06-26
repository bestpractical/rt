use strict;
use warnings;

use RT::Test
    tests   => undef,
    plugins => [qw(RT::Extension::PSGIWrap)];

my ($base, $m) = RT::Test->started_ok;
$m->login;
ok(my $res = $m->get("/"));
is($res->code, 200, 'Successful request to /');
ok($res->header('X-RT-PSGIWrap'), 'X-RT-PSGIWrap header set from the plugin');

done_testing();
