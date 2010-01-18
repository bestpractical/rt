#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 15, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

# edit user rights
my $user_foo = RT::Test->load_or_create_user(
    name     => 'user_foo',
    password => 'password',
);
ok( $user_foo->id, 'loaded or created user_foo' );
ok( !$user_foo->has_right( right => 'CreateTicket', object => RT->system ),
    'no CreateTicket right for user_foo' );

my $group_foo = RT::Model::Group->new;
$group_foo->load_acl_equivalence($user_foo);

$agent->get_ok('/admin/global/user_rights');
my $moniker = 'global_edit_user_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $group_foo->id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( ('Updated rights') x 2 );
RT::Model::Principal->invalidate_acl_cache();
ok(
    $user_foo->has_right(
        right  => 'CreateTicket',
        object => RT->system
    ),
    'CreateTicket right for user_foo'
);

# edit global rights
my $privileged = RT::Model::Group->new( current_user => RT->system_user );
ok( $privileged->load_system_internal('privileged'), 'load group privileged' );

ok(
    !$privileged->principal->has_right(
        right  => 'CreateTicket',
        object => RT->system
    ),
    'no CreateTicket right for privileged'
);

$agent->get_ok('/admin/global/group_rights');
my $moniker = 'global_edit_group_rights';
$agent->fill_in_action_ok( $moniker,
    'rights_' . $privileged->id => 'CreateTicket' );
$agent->submit;
$agent->content_contains( ('Updated rights') x 2 );

RT::Model::Principal->invalidate_acl_cache();
ok(
    $privileged->principal->has_right(
        right  => 'CreateTicket',
        object => RT->system
    ),
    'CreateTicket right for privileged'
);

