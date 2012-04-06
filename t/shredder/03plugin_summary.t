
use strict;
use warnings;

use RT::Test::Shredder nodb => 1, tests => 4;

use_ok('RT::Shredder::Plugin');
my $plugin_obj = RT::Shredder::Plugin->new;
isa_ok($plugin_obj, 'RT::Shredder::Plugin');
my ($status, $msg) = $plugin_obj->LoadByName('Summary');
ok($status, 'loaded summary plugin') or diag "error: $msg";
isa_ok($plugin_obj, 'RT::Shredder::Plugin::Summary');

