#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 44, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

$agent->get_ok('/admin/groups/');

ok(
    $agent->find_link( text => 'Include disabled ones in listing', ),
    'include disabled link',
);

my $moniker = $agent->moniker_for('RT::Action::CreateGroup');
$agent->fill_in_action_ok( $moniker, name => 'group_foo', );

$agent->submit;
$agent->content_contains( 'Created', 'created group_foo' );
my $group_foo = RT::Model::Group->new( current_user => RT->system_user );
ok( $group_foo->load_user_defined('group_foo'), 'did create group_foo' );

$agent->follow_link_ok( { text => 'group_foo' }, 'group_foo link' );

# create a disabled group
$agent->fill_in_action_ok( $moniker, 'name' => 'group_bar', disabled => 1 );
$agent->submit;
$agent->content_contains( 'Created', 'created group_bar' );
my $group_bar = RT::Model::Group->new( current_user => RT->system_user );
ok( $group_bar->load_user_defined('group_bar'), 'did create group_bar' );

ok(
    !$agent->find_link( text => 'group_bar' ),
    'disabled group_bar is not shown'
);

$agent->follow_link_ok( { text => 'Include disabled ones in listing' },
    'follow include disabled link' );
ok(
    $agent->find_link( text => 'group_bar' ),
    'disabled group_bar is shown with include_disabled'
);
ok(
    $agent->find_link( text => 'Exclude disabled ones in listing', ),
    'exclude disabled link',
);

$agent->get_ok('/admin/groups/');
$agent->follow_link_ok( { text => 'group_foo' }, 'follow group_foo link' );

# Basics
$agent->follow_link_ok( { text => 'Basics' }, 'follow Basic link' );
$moniker = 'update_group';
$agent->fill_in_action_ok( $moniker, name => 'group_foo_foo' );
$agent->submit;
$agent->content_contains( 'Updated', 'Update name' );
ok( $group_foo->load_user_defined('group_foo_foo'), 'reload group_foo' );
is( $group_foo->name,       'group_foo_foo', 'did change name to group_foo_foo' );

# Group Rights
$agent->follow_link_ok( { text => 'Group Rights' },
    'follow Group Rights link' );
my $privileged = RT::Model::Group->new( current_user => RT->system_user );
ok( $privileged->load_system_internal('privileged'), 'load group privileged' );
$moniker = 'group_edit_group_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $privileged->id => 'SeeGroup' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated group rights' );
my $acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($group_foo);
$acl_obj->limit_to_principal( id => $privileged->id );
is( $acl_obj->first->right_name, 'SeeGroup', 'privileged can see group_foo' );

# User Rights
$agent->follow_link_ok( { text => 'User Rights' }, 'follow User Rights link' );

my $root_group = RT::Model::Group->new( current_user => RT->system_user );
$root_group->load_acl_equivalence($root);
$moniker = 'group_edit_user_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $root_group->principal_id => 'SeeGroup' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated user rights' );

$acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($group_foo);
$acl_obj->limit_to_principal( id => $root->id );
is( $acl_obj->first->right_name, 'SeeGroup', 'current user can see group_foo' );

# Members
$agent->follow_link_ok( { text => 'Members' }, 'follow Members link' );

$moniker = 'group_edit_members';
$agent->fill_in_action_ok( $moniker, 'users' => $root->id );
$agent->submit;
$agent->content_contains( 'Updated group members', 'updated group members' );
is( $group_foo->user_members->first->id, $root->id, 'did add root to group_foo' );

# History
$agent->follow_link_ok( { text => 'History' }, 'follow History link' );
$agent->content_contains( 'Group Created', 'contains Created history' );
$agent->content_contains( "name changed", 'contains name changed history' );

# Custom Fields
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
ok(
    $cf->create(
        name        => 'group_cf_foo',
        lookup_type => $group_foo->custom_field_lookup_type,
        type        => 'Freeform',
    ),
    'create group_cf_foo'
);

$agent->follow_link_ok(
    {
        text      => 'Custom Fields',
        url_regex => qr/select_custom_fields/,
    },
    'follow Custom Fields link'
);
$moniker = 'group_select_cfs';
$agent->fill_in_action_ok( $moniker, 'cfs' => $cf->id );
$agent->submit;
$agent->content_contains(
    'Updated custom fields selection', 'updated custom field selection'
);

my $object_cfs =
  RT::Model::ObjectCustomFieldCollection->new(
    current_user => RT->system_user );
$object_cfs->find_all_rows;
$object_cfs->limit_to_object_id( $group_foo->id );
$object_cfs->limit_to_lookup_type('RT::Model::Group');
ok( $object_cfs->has_entry_for_custom_field( $cf->id ),
    'we did select group_cf_foo' );
