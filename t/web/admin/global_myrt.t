#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 6, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/my_rt');
my $moniker = 'global_config_my_rt';
$agent->fill_in_action_ok(
    $moniker,
    body    => [ 'system-MyTickets', 'component-MyReminders' ],
    summary => 'component-CreateTicket',
);

$agent->submit;
$agent->content_contains(
    'Updated myrt', 'updated myrt'
);

my ($settings) = RT->system->attributes->named('HomepageSettings');
is_deeply(
    $settings->content,
    {
        'body' => [
            {
                'name' => 'MyTickets',
                'type' => 'system'
            },
            {
                'name' => 'MyReminders',
                'type' => 'component'
            }
        ],
        'summary' => [
            {
                'name' => 'CreateTicket',
                'type' => 'component'
            }
        ]
    },
    'myrt is indeed updated'
);

