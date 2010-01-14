#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 37, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

$agent->get_ok('/admin/custom_fields/');

ok(
    $agent->find_link( text => 'Include disabled ones in listing', ),
    'include disabled link',
);


my $moniker = $agent->moniker_for('RT::Action::CreateCustomField');
$agent->fill_in_action_ok(
    $moniker,
    'name'      => 'cf_foo',
    lookup_type => 'RT::Model::Queue-RT::Model::Ticket',
);

$agent->submit;
$agent->content_contains( 'Created', 'created cf_foo' );
my $cf_foo = RT::Model::CustomField->new( current_user => RT->system_user );
ok( $cf_foo->load('cf_foo'), 'did create cf_foo' );

$agent->follow_link_ok( { text => 'cf_foo' }, 'cf_foo link' );

# create a disabled cf
$agent->fill_in_action_ok( $moniker, 'name' => 'cf_bar', disabled => 1 );
$agent->submit;
$agent->content_contains( 'Created', 'created cf_bar' );
my $cf_bar = RT::Model::CustomField->new( current_user => RT->system_user );
ok( $cf_bar->load('cf_bar'), 'did create cf_bar' );

ok( !$agent->find_link( text => 'cf_bar' ), 'disabled cf_bar is not shown' );

$agent->follow_link_ok( { text => 'Include disabled ones in listing' },
    'follow include disabled link' );
ok(
    $agent->find_link( text => 'cf_bar' ),
    'disabled cf_bar is shown with include_disabled'
);
ok(
    $agent->find_link( text => 'Exclude disabled ones in listing', ),
    'exclude disabled link',
);


$agent->get_ok('/admin/custom_fields/');
$agent->follow_link_ok( { text => 'cf_foo' },
    'follow cf_foo link' );

# Basics
$agent->follow_link_ok( { text => 'Basics' }, 'follow Basic link' );
$moniker = 'update_customfield';
$agent->fill_in_action_ok( $moniker, max_values => 1 );
$agent->submit;
$agent->content_contains( 'Updated', 'updated max_vaues' );
ok( $cf_foo->load( 'cf_foo'), 'reload cf_foo' );
is( $cf_foo->max_values, 1, 'did change max_values to 1' );

# Group Rights
$agent->follow_link_ok( { text => 'Group Rights' },
    'follow Group Rights link' );
my $privileged = RT::Model::Group->new( current_user => RT->system_user );
ok( $privileged->load_system_internal('privileged'), 'load group privileged' );
$moniker = 'cf_edit_group_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $privileged->id => 'SeeCustomField' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated group rights' );
my $acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($cf_foo);
$acl_obj->limit_to_principal( id => $privileged->id );
is( $acl_obj->first->right_name,
    'SeeCustomField', 'privileged can see cf_foo' );

# User Rights
$agent->follow_link_ok( { text => 'User Rights' }, 'follow User Rights link' );

my $root_group = RT::Model::Group->new( current_user => RT->system_user );
$root_group->load_acl_equivalence($root);
$moniker = 'cf_edit_user_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $root_group->principal_id => 'SeeCustomField' );
$agent->submit;
$agent->content_contains( 'Updated rights', 'updated user rights' );

$acl_obj = RT::Model::ACECollection->new( current_user => RT->system_user );
$acl_obj->limit_to_object($cf_foo);
$acl_obj->limit_to_principal( id => $root->id );
is( $acl_obj->first->right_name,
    'SeeCustomField', 'current user can see cf_foo' );

# Applies to
$agent->follow_link_ok( { text => 'Applies To' },
    'follow Applies To link' );

$moniker = 'cf_select_ocfs';
$agent->fill_in_action_ok( $moniker, 'objects' => 1 );
$agent->submit;
$agent->content_contains( 'Updated object custom fields selection',
    'select General' );

my $object_cfs =
  RT::Model::ObjectCustomFieldCollection->new(
    current_user => RT->system_user );
$object_cfs->find_all_rows;
$object_cfs->limit_to_custom_field($cf_foo->id);
is( $object_cfs->count, 1, 'we select only 1 queue' );
is( $object_cfs->first->object_id, 1, 'the only 1 queue is General' );


