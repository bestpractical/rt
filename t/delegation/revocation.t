#!/usr/bin/perl -w

use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 22;

use RT;



my ($u1, $g1, $pg1, $pg2, $ace, @groups, @users, @principals);
@groups = (\$g1, \$pg1, \$pg2);
@users = (\$u1);
@principals = (@groups, @users);

my($ret, $msg);

$u1 = RT::Model::User->new(current_user => RT->system_user);
( $ret, $msg ) = $u1->load_or_create_by_email('delegtest1@example.com');
ok( $ret, "Load / Create test user 1: $msg" );
$u1->set_privileged(1);

$g1 = RT::Model::Group->new(current_user => RT->system_user);
( $ret, $msg) = $g1->load_user_defined_group('dg1');
unless ($ret) {
    ( $ret, $msg ) = $g1->create_user_defined_group( name => 'dg1' );
}
$pg1 = RT::Model::Group->new(current_user => RT->system_user);
( $ret, $msg ) = $pg1->load_personal_group( name => 'dpg1',
					  User => $u1->principal_id );
unless ($ret) {
    ( $ret, $msg ) = $pg1->create_personal_group( name => 'dpg1',
						principal_id => $u1->principal_id );
}
ok( $ret, "Load / Create test personal group 1: $msg" );
$pg2 = RT::Model::Group->new(current_user => RT->system_user);
( $ret, $msg ) = $pg2->load_personal_group( name => 'dpg2',
					  User => $u1->principal_id );
unless ($ret) {
    ( $ret, $msg ) = $pg2->create_personal_group( name => 'dpg2',
						principal_id => $u1->principal_id );
}
ok( $ret, "Load / Create test personal group 2: $msg" );

clear_acls_and_groups();

( $ret, $msg ) = $u1->principal_object->grant_right( right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to u1: $msg" );
( $ret, $msg ) = $g1->principal_object->grant_right( right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g1: $msg" );
( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );

$ace = RT::Model::ACE->new(current_user => RT::CurrentUser->new( id => $u1->id) );
( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'ShowConfigTab',
    object        => RT->system,
    principal_type => 'Group',
    principal_id   => $g1->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg2->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok(( $pg1->principal_object->has_right( right  => 'ShowConfigTab',
				   object => RT->system ) and
     $pg2->principal_object->has_right( right  => 'ShowConfigTab',
				   object => RT->system )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->delete_member( $u1->principal_id );
ok( $ret, "Delete test user 1 from g1: $msg" );

ok( not( $pg1->principal_object->has_right( right  => 'ShowConfigTab',
				       object => RT->system )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->principal_object->has_right( right  => 'ShowConfigTab',
				       object => RT->system )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );

( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg2->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok(( $pg1->principal_object->has_right( right  => 'ShowConfigTab',
				   object => RT->system ) and
     $pg2->principal_object->has_right( right  => 'ShowConfigTab',
				   object => RT->system )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->principal_object->revoke_right( right => 'ShowConfigTab' );
ok( $ret, "Revoke ShowConfigTab from g1: $msg" );

ok( not( $pg1->principal_object->has_right( right  => 'ShowConfigTab',
				       object => RT->system )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->principal_object->has_right( right  => 'ShowConfigTab',
				       object => RT->system )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );



#######

sub clear_acls_and_groups {
    # Revoke all rights granted to our cast
    my $acl = RT::Model::ACECollection->new(current_user => RT->system_user);
    foreach (@principals) {
	$acl->limit_to_principal(type => $$_->principal_object->principal_type,
			       id => $$_->principal_object->id);
    }
    while (my $ace = $acl->next()) {
	$ace->delete();
    }

    # Remove all group memberships
    my $members = RT::Model::GroupMemberCollection->new(current_user => RT->system_user);
    foreach (@groups) {
	$members->limit_to_members_of_group( $$_->principal_id );
    }
    while (my $member = $members->next()) {
	$member->delete();
    }

    $acl->redo_search();
    is( $acl->count() , 0,
       "All principals have no rights after clearing ACLs" );
    $members->redo_search();
    is( $members->count() , 0,
       "All groups have no members after clearing groups" );
}
