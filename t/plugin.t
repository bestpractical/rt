#!/usr/bin/perl
use strict;
use warnings;

# XXX TODO temporarily not run this test by default because this will ruin
# your database in etc/config.yml.

BEGIN {
    use Test::More;
    unless (@ARGV) {
        plan skip_all => 'this will ruin your database in etc/config.yml';
    }
    else {
        plan tests => 5;
    }
}

BEGIN {
    use RT;
    my $local_lib = Jifty::Util->app_root . '/local/lib';
    use lib $local_lib; # plugin need this path in @INC
    RT->load_config;
    $RT::LocalPluginPath = $RT::BASE_PATH . "/t/plugins";
    RT->config->set( 'plugins', 'RT::Extension::Test' );
    ok( RT->plugins->[0]->name, 'RT-Extension-Test' );
}

use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;
$agent->get_ok($baseurl);
$agent->get_ok($baseurl . '/NoAuth/test.html');
like( $agent->content, qr/testtest/ );
