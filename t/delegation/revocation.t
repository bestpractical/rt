#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More; 
plan tests => 22;

use RT;

use RT::Test;

my ($u1, $g1, $pg1, $pg2, $ace, @groups, @users, @principals);
@groups = (\$g1, \$pg1, \$pg2);
@users = (\$u1);
@principals = (@groups, @users);

my($ret, $msg);

$u1 = RT::Model::User->new($RT::SystemUser);
( $ret, $msg ) = $u1->load_or_create_by_email('delegtest1@example.com');
ok( $ret, "Load / Create test user 1: $msg" );
$u1->set_Privileged(1);

$g1 = RT::Model::Group->new($RT::SystemUser);
( $ret, $msg) = $g1->loadUserDefinedGroup('dg1');
unless ($ret) {
    ( $ret, $msg ) = $g1->create_userDefinedGroup( Name => 'dg1' );
}
$pg1 = RT::Model::Group->new($RT::SystemUser);
( $ret, $msg ) = $pg1->loadPersonalGroup( Name => 'dpg1',
					  User => $u1->PrincipalId );
unless ($ret) {
    ( $ret, $msg ) = $pg1->createPersonalGroup( Name => 'dpg1',
						PrincipalId => $u1->PrincipalId );
}
ok( $ret, "Load / Create test personal group 1: $msg" );
$pg2 = RT::Model::Group->new($RT::SystemUser);
( $ret, $msg ) = $pg2->loadPersonalGroup( Name => 'dpg2',
					  User => $u1->PrincipalId );
unless ($ret) {
    ( $ret, $msg ) = $pg2->createPersonalGroup( Name => 'dpg2',
						PrincipalId => $u1->PrincipalId );
}
ok( $ret, "Load / Create test personal group 2: $msg" );

clear_acls_and_groups();

( $ret, $msg ) = $u1->PrincipalObj->GrantRight( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to u1: $msg" );
( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g1: $msg" );
( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );

$ace = RT::Model::ACE->new($u1);
( $ret, $msg ) = $ace->load_by_values(
    RightName     => 'ShowConfigTab',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g1->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg2->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok(( $pg1->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				   Object => $RT::System ) and
     $pg2->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				   Object => $RT::System )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->delete_member( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );

ok( not( $pg1->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );

( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg2->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok(( $pg1->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				   Object => $RT::System ) and
     $pg2->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				   Object => $RT::System )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->PrincipalObj->RevokeRight( Right => 'ShowConfigTab' );
ok( $ret, "Revoke ShowConfigTab from g1: $msg" );

ok( not( $pg1->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->PrincipalObj->has_right( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );



#######

sub clear_acls_and_groups {
    # Revoke all rights granted to our cast
    my $acl = RT::Model::ACECollection->new($RT::SystemUser);
    foreach (@principals) {
	$acl->LimitToPrincipal(Type => $$_->PrincipalObj->PrincipalType,
			       Id => $$_->PrincipalObj->id);
    }
    while (my $ace = $acl->next()) {
	$ace->delete();
    }

    # Remove all group memberships
    my $members = RT::Model::GroupMemberCollection->new($RT::SystemUser);
    foreach (@groups) {
	$members->LimitToMembersOfGroup( $$_->PrincipalId );
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
