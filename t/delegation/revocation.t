#!/usr/bin/perl -w

use strict;
use warnings;

use RT;

use RT::Test tests => 22;

my ($u1, $g1, $pg1, $pg2, $ace, @groups, @users, @principals);
@groups = (\$g1, \$pg1, \$pg2);
@users = (\$u1);
@principals = (@groups, @users);

my($ret, $msg);

$u1 = RT::User->new($RT::SystemUser);
( $ret, $msg ) = $u1->LoadOrCreateByEmail('delegtest1@example.com');
ok( $ret, "Load / Create test user 1: $msg" );
$u1->SetPrivileged(1);

$g1 = RT::Group->new($RT::SystemUser);
( $ret, $msg) = $g1->LoadUserDefinedGroup('dg1');
unless ($ret) {
    ( $ret, $msg ) = $g1->CreateUserDefinedGroup( Name => 'dg1' );
}
$pg1 = RT::Group->new($RT::SystemUser);
( $ret, $msg ) = $pg1->LoadPersonalGroup( Name => 'dpg1',
					  User => $u1->PrincipalId );
unless ($ret) {
    ( $ret, $msg ) = $pg1->CreatePersonalGroup( Name => 'dpg1',
						PrincipalId => $u1->PrincipalId );
}
ok( $ret, "Load / Create test personal group 1: $msg" );
$pg2 = RT::Group->new($RT::SystemUser);
( $ret, $msg ) = $pg2->LoadPersonalGroup( Name => 'dpg2',
					  User => $u1->PrincipalId );
unless ($ret) {
    ( $ret, $msg ) = $pg2->CreatePersonalGroup( Name => 'dpg2',
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

$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
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

ok(( $pg1->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				   Object => $RT::System ) and
     $pg2->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				   Object => $RT::System )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );

ok( not( $pg1->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );

( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg2->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok(( $pg1->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				   Object => $RT::System ) and
     $pg2->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				   Object => $RT::System )),
   "Test personal groups have ShowConfigTab right after delegation" );

( $ret, $msg ) = $g1->PrincipalObj->RevokeRight( Right => 'ShowConfigTab' );
ok( $ret, "Revoke ShowConfigTab from g1: $msg" );

ok( not( $pg1->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 1 lacks ShowConfigTab after user removed from g1" );
ok( not( $pg2->PrincipalObj->HasRight( Right  => 'ShowConfigTab',
				       Object => $RT::System )),
    "Test personal group 2 lacks ShowConfigTab after user removed from g1" );



#######

sub clear_acls_and_groups {
    # Revoke all rights granted to our cast
    my $acl = RT::ACL->new($RT::SystemUser);
    foreach (@principals) {
	$acl->LimitToPrincipal(Type => $$_->PrincipalObj->PrincipalType,
			       Id => $$_->PrincipalObj->Id);
    }
    while (my $ace = $acl->Next()) {
	$ace->Delete();
    }

    # Remove all group memberships
    my $members = RT::GroupMembers->new($RT::SystemUser);
    foreach (@groups) {
	$members->LimitToMembersOfGroup( $$_->PrincipalId );
    }
    while (my $member = $members->Next()) {
	$member->Delete();
    }

    $acl->RedoSearch();
    is( $acl->Count() , 0,
       "All principals have no rights after clearing ACLs" );
    $members->RedoSearch();
    is( $members->Count() , 0,
       "All groups have no members after clearing groups" );
}
