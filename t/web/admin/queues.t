#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 33, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load( 'root' ), 'load user root' );

$agent->get_ok('/admin/queues/');

ok( $agent->find_link( text => 'General', url_regex => qr{\?id=1}, ),
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
my $cc_group = $queue->role_group( 'cc' );
ok( $cc_group->has_member( principal => $root ),
    'cc role contains current user' );

$agent->follow_link_ok( { text => 'Group Rights' }, 'follow Group Rights link' );
my $privileged = RT::Model::Group->new( current_user => RT->system_user );
ok( $privileged->load_system_internal( 'privileged' ), 'load group privileged' );
$moniker = 'queue_edit_group_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $privileged->id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated group rights' );
my $acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($queue);
$acl_obj->limit_to_principal( id => $privileged->id );
is( $acl_obj->first->right_name, 'CreateTicket',
    'privileged can create ticket in General' );

$agent->follow_link_ok( { text => 'User Rights' }, 'follow User Rights link' );

my $root_group = RT::Model::Group->new( current_user => RT->system_user );
$root_group->load_acl_equivalence( $root );
$moniker = 'queue_edit_user_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $root_group->principal_id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated user rights' );

$acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($queue);
$acl_obj->limit_to_principal( id => $root->id );
is( $acl_obj->first->right_name, 'CreateTicket',
    'current user can create ticket in General' );

$agent->follow_link_ok( { text => 'Ticket Custom Fields' },
    'follow Ticket Custom Fields link' );
$agent->follow_link_ok( { text => 'Transaction Custom Fields' }, 'follow Transaction Custom Fields link' );
$agent->follow_link_ok( { text => 'GnuPG' }, 'follow GnuPG link' );
$agent->follow_link_ok( { text => 'Templates' }, 'follow Templates link' );

