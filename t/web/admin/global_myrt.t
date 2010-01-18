#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 5, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/my_rt');
my $moniker = 'global_config_my_rt';
$agent->fill_in_action_ok(
    $moniker,
    summary      => 'component-CreateTicket',
);

$agent->submit;
$agent->content_contains(
    'Updated myrt', 'updated myrt'
);

