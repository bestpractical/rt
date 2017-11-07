use strict;
use warnings;

BEGIN {
    use Test::More;
    plan skip_all => "Testing the rt-server init sequence in isolation requires Apache"
        unless ($ENV{RT_TEST_WEB_HANDLER} || '') =~ /^apache/;
}

use JSON qw(from_json);

use RT::Test
    tests   => undef,
    plugins => ["Overlays"];

my ($base, $m) = RT::Test->started_ok;

# Check that the overlay was actually loaded
$m->get_ok("$base/overlay_loaded");
is $m->content, "yes", "Plugin's RT/User_Local.pm was loaded";

# Check accessible is correct and doesn't need to be rebuilt from overlay
$m->get_ok("$base/user_accessible");
ok $m->content, "Received some content";

my $info = from_json($m->content) || {};
ok $info->{Comments}{public}, "User.Comments is marked public via overlay";

done_testing;
