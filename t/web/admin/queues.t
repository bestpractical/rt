#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 45, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

$agent->get_ok('/admin/queues/');

ok( $agent->find_link( text => 'General', url_regex => qr{\?id=\d+$}, ),
    "General link" );

ok( !$agent->find_link( text => '___Approvals', ), "no ___Approvals link" );

ok(
    $agent->find_link( text => 'Include disabled ones in listing', ),
    'include disabled link',
);

$agent->follow_link_ok( { text => 'Include disabled ones in listing' },
    'follow include disabled link' );
ok( $agent->find_link( text => '___Approvals', ), "___Approvals link" );

ok(
    $agent->find_link( text => 'Exclude disabled ones in listing', ),
    'exclude disabled link',
);

$agent->follow_link_ok( { text => 'General', url_regex => qr{\?id=1} },
    'follow General link' );

# Basics
$agent->follow_link_ok( { text => 'Basics' }, 'follow Basic link' );
my $moniker = 'update_queue';
$agent->fill_in_action_ok( $moniker, initial_priority => 30 );
$agent->submit;
$agent->content_contains( 'Updated', 'updated queue' );
my $queue = RT::Model::Queue->new( current_user => RT->system_user );
ok( $queue->load('General'), 'load queue Generall' );
is( $queue->initial_priority, 30, 'initial_priority is indeed updated' );

# Watchers
$agent->follow_link_ok( { text => 'Watchers' }, 'follow Watchers link' );
$moniker = 'queue_edit_watchers';
$agent->fill_in_action_ok( $moniker, cc_users => $root->id );
$agent->submit;
$agent->content_contains( 'Updated watchers', 'updated watchers' );
my $cc_group = $queue->role_group('cc');
ok( $cc_group->has_member( principal => $root ),
    'cc role contains current user' );

# Group Rights
$agent->follow_link_ok( { text => 'Group Rights' },
    'follow Group Rights link' );
my $privileged = RT::Model::Group->new( current_user => RT->system_user );
ok( $privileged->load_system_internal('privileged'), 'load group privileged' );

ok(
    !$privileged->principal->has_right(
        right  => 'CreateTicket',
        object => $queue
    ),
    'no CreateTicket right for privileged'
);

$moniker = 'queue_edit_group_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $privileged->id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated group rights' );

RT::Model::Principal->invalidate_acl_cache();
ok(
    $privileged->principal->has_right(
        right  => 'CreateTicket',
        object => $queue
    ),
    'CreateTicket right for privileged'
);

# User Rights
$agent->follow_link_ok( { text => 'User Rights' }, 'follow User Rights link' );
ok(
    $root->has_right(
        right  => 'CreateTicket',
        object => $queue
    ),
    'CreateTicket right for root'
);

my $root_group = RT::Model::Group->new( current_user => RT->system_user );
$root_group->load_acl_equivalence($root);
ok(
    $root->has_right(
        right  => 'CreateTicket',
        object => $queue
    ),
    'CreateTicket right for root'
);
$moniker = 'queue_edit_user_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $root_group->principal_id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated user rights' );

RT::Model::Principal->invalidate_acl_cache();
ok(
    $root->has_right(
        right  => 'CreateTicket',
        object => $queue
    ),
    'CreateTicket right for root'
);

my $cf = RT::Model::CustomField->new( current_user => RT->system_user );

ok(
    $cf->create(
        name        => 'cf_123',
        type        => 'Freeform',
        lookup_type => 'RT::Model::Queue-RT::Model::Ticket',
    ),
    'created cf cf_123 for ticket'
);

$agent->follow_link_ok( { text => 'Ticket Custom Fields' },
    'follow Ticket Custom Fields link' );

$moniker = 'queue_select_cfs';
$agent->fill_in_action_ok( $moniker, 'cfs' => $cf->id );
$agent->submit;
$agent->content_contains( 'Updated custom fields selection', 'select cf_123' );

my $object_cfs =
  RT::Model::ObjectCustomFieldCollection->new(
    current_user => RT->system_user );
$object_cfs->find_all_rows;
$object_cfs->limit_to_object_id( $queue->id );
$object_cfs->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
ok( $object_cfs->has_entry_for_custom_field( $cf->id ),
    'we did select cf_123' );

$agent->follow_link_ok(
    { text => 'Transaction Custom Fields' },
    'follow Transaction Custom Fields link'
);
$agent->follow_link_ok( { text => 'GnuPG' },     'follow GnuPG link' );
$agent->follow_link_ok( { text => 'Templates' }, 'follow Templates link' );

# let's create a queue
$agent->get_ok('/admin/queues/');
my $moniker = $agent->moniker_for('RT::Action::CreateQueue');
$agent->fill_in_action_ok( $moniker, 'name' => 'queue_foo' );
$agent->submit;
$agent->content_contains( 'Created', 'created queue_foo' );
my $queue_foo = RT::Model::Queue->new( current_user => RT->system_user );
ok( $queue_foo->load('queue_foo'), 'did create queue_foo' );
$agent->follow_link_ok( { text => 'General', url_regex => qr{\?id=\d+$} },
    "queue_foo link" );

