#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 39, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

$agent->get_ok('/admin/users/');

ok(
    $agent->find_link( text => 'Include disabled ones in listing', ),
    'include disabled link',
);

my $moniker = $agent->moniker_for('RT::Action::CreateUser');
$agent->fill_in_action_ok(
    $moniker,
    name             => 'user_foo',
    email            => 'user_foo@localhost',
    password         => 'password',
    password_confirm => 'password',
    privileged       => 1,
);

$agent->submit;
$agent->content_contains( 'Created', 'created user_foo' );
my $user_foo = RT::Model::User->new( current_user => RT->system_user );
ok( $user_foo->load('user_foo'), 'did create user_foo' );
$agent->follow_link_ok( { text => 'user_foo' }, 'user_foo link' );

# create a disabled user
$agent->fill_in_action_ok(
    $moniker,
    name             => 'user_bar',
    email            => 'user_bar@localhost',
    password         => 'password',
    password_confirm => 'password',
    privileged       => 1,
    disabled         => 1,
);
$agent->submit;
$agent->content_contains( 'Created', 'created user_bar' );
my $user_bar = RT::Model::User->new( current_user => RT->system_user );
ok( $user_bar->load('user_bar'), 'did create user_bar' );

ok(
    !$agent->find_link( text => 'user_bar' ),
    'disabled user_bar is not shown'
);

$agent->follow_link_ok( { text => 'Include disabled ones in listing' },
    'follow include disabled link' );
ok(
    $agent->find_link( text => 'user_bar' ),
    'disabled user_bar is shown with include_disabled'
);
ok(
    $agent->find_link( text => 'Exclude disabled ones in listing', ),
    'exclude disabled link',
);

$agent->get_ok('/admin/users/');
$agent->follow_link_ok( { text => 'user_foo' }, 'follow user_foo link' );

# Basics
$agent->follow_link_ok( { text => 'Basics' }, 'follow Basic link' );
$moniker = 'update_user';
$agent->fill_in_action_ok(
    $moniker,
    name             => 'user_foo_foo',
    password         => 'password',
    password_confirm => 'password'
);

$agent->submit;
$agent->content_contains( 'Updated', 'Update name' );
ok( $user_foo->load('user_foo_foo'), 'reload user_foo' );
is( $user_foo->name,       'user_foo_foo', 'did change name to user_foo_foo' );

# Memberships
my $group = RT::Model::Group->new( current_user => RT->system_user );
ok( $group->create_user_defined( name => 'group_foo' ), 'create group_foo' );

$agent->follow_link_ok( { text => 'Memberships' }, 'follow Memberships link' );
$moniker = 'user_edit_memberships';
$agent->fill_in_action_ok( $moniker, groups => $group->id );
$agent->submit;
$agent->content_contains( 'Updated user memberships',
    'updated user memberships' );
my $is_member =
  RT::Model::GroupCollection->new( current_user => RT->system_user );
$is_member->limit_to_user_defined_groups;
$is_member->with_member( principal => $user_foo->id );
is( $is_member->first->id, $group->id, 'did add user_foo to group_foo' );

# History
$agent->follow_link_ok( { text => 'History' }, 'follow History link' );
$agent->content_contains( 'User Created', 'contains Created history' );

# Custom Fields
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
ok(
    $cf->create(
        name        => 'user_cf_foo',
        lookup_type => $user_foo->custom_field_lookup_type,
        type        => 'Freeform',
    ),
    'create user_cf_foo'
);

$agent->follow_link_ok(
    {
        text      => 'Custom Fields',
        url_regex => qr/select_custom_fields/,
    },
    'follow Custom Fields link'
);
$moniker = 'user_select_cfs';
$agent->fill_in_action_ok( $moniker, 'cfs' => $cf->id );
$agent->submit;
$agent->content_contains(
    'Updated custom fields selection', 'updated custom field selection'
);

my $object_cfs =
  RT::Model::ObjectCustomFieldCollection->new(
    current_user => RT->system_user );
$object_cfs->find_all_rows;
$object_cfs->limit_to_object_id( $user_foo->id );
$object_cfs->limit_to_lookup_type('RT::Model::User');
ok( $object_cfs->has_entry_for_custom_field( $cf->id ),
    'we did select user_cf_foo' );

# RT at a glance
my $user_foo_id = $user_foo->id;
$agent->follow_link_ok(
    {
        text      => 'RT at a glance',
        url_regex => qr!admin/users/my_rt\?id=$user_foo_id!,
    },
    'follow RT at a glance link'
);
$moniker = 'user_config_my_rt';
$agent->fill_in_action_ok(
    $moniker,
    summary_rows => 100,
    summary      => 'component-CreateTicket',
);

$agent->submit;
$agent->content_contains(
    'Updated myrt', 'updated myrt'
);
$user_foo->preferences( 'SummaryRows', 100, 'did update summary_rows to 100' );

# GnuPG
ok(
    !$agent->find_link( text => 'GnuPG' ),
    'no gnupg link'
);
#$agent->follow_link_ok( { text => 'GnuPG' }, 'follow GnuPG link' );

