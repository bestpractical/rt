#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 6, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/system');
$agent->follow_link_ok( { text => 'Base' }, 'follow Base link' );
my $moniker = 'global_config_system';
$agent->fill_in_action_ok(
    $moniker,
    rtname      => q{'foo'},
);
$agent->submit;

is( RT->config->get('rtname'), 'foo', 'rtname is updated' );
