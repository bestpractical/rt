#!/usr/bin/perl
use strict;
use warnings;

# XXX TODO temporarily not run this test by default because this will ruin
# your database in etc/config.yml.

BEGIN {
    unless (@ARGV) {
        print "1..1\nok 1\nDone\n";
        exit 0;
    }
}

use Test::More tests => 5;
BEGIN {
    use RT;
    use lib $RT::LocalLibPath; # plugin need this path in @INC
    RT->load_config;
    $RT::LocalPluginPath = $RT::BASE_PATH . "/t/plugins";
    RT->config->set( 'Plugins', 'RT::Extension::Test' );
    ok( RT->plugins->[0]->name, 'RT-Extension-Test' );
}

use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;
$agent->get_ok($baseurl);
$agent->get_ok($baseurl . '/NoAuth/test.html');
like( $agent->content, qr/testtest/ );
