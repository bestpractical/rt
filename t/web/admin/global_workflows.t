#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 22, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/workflows/');

ok(
    $agent->find_link(
        text      => 'default',
        url_regex => qr{/admin/global/workflows/},
    ),
    "default link"
);

my $moniker = $agent->moniker_for('RT::Action::CreateWorkflow');
$agent->fill_in_action_ok( $moniker, 'name' => 'workflow_foo', );
$agent->submit;
$agent->content_contains( 'Created', 'created workflow_foo' );
my $workflow_foo = RT::Workflow->new( current_user => RT->system_user );
ok( $workflow_foo->load('workflow_foo'), 'load workflow_foo' );
is( $workflow_foo->name, 'workflow_foo', 'did create workflow_foo' );

$agent->follow_link_ok( { text => 'workflow_foo' }, "follow Transitions link" );

# Modify Statuses
$agent->follow_link_ok( { text => 'Modify Statuses' },
    'follow Modify Statuses link' );
$moniker = 'workflow_edit_statuses';
$agent->fill_in_action_ok(
    $moniker,
    active   => 'open',
    inactive => 'resolved',
    initial  => 'new',
);

$agent->submit;
$agent->content_contains( 'Updated', 'updated workflow statuses' );

# Modify Transitions
$agent->follow_link_ok( { text => 'Transitions' }, "follow Transitions link" );
$moniker = 'workflow_edit_transitions';
$agent->fill_in_action_ok(
    $moniker,
    'new'      => 'open',
    'open'     => 'resolved',
    'resolved' => 'open',
);

$agent->submit;
$agent->content_contains( ('Updated workflow transitions') x 2 );

# Interface
$agent->follow_link_ok( { text => 'Interface' }, "follow Interface link" );
$moniker = 'workflow_edit_interface';
$agent->fill_in_action_ok(
    $moniker,
    'new___label___open'  => 'open',
    'new___action___open' => 'respond',
);
$agent->submit;
$agent->content_contains( ('Updated workflow interface') x 2 );

# Mappings
$agent->follow_link_ok( { text => 'Summary' }, "follow Summary link" );
$agent->follow_link_ok(
    { url_regex => qr{workflows/mappings\?from=default&to=workflow_foo} },
    "follow Mappings link" );

$moniker = 'workflow_edit_mappings';
$agent->fill_in_action_ok(
    $moniker,
    from_stalled => 'open',
    from_deleted => 'resolved',
    from_rejected => 'resolved',
);

$agent->submit;
$agent->content_contains( ('Updated workflow mappings') x 2 );

