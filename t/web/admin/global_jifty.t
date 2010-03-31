#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 4, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/config_jifty');
ok( $agent->moniker_for('RT::Action::Config'), 'found moniker' );
