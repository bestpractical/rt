#!/usr/bin/perl -w
use strict;
use warnings;

# Regression test suite for http://rt3.fsck.com/Ticket/Display.html?id=6184
# and related corner cases related to cleanup of delegated ACEs when
# the delegator loses the right to delegate.  This causes complexities
# due to the fact that multiple ACEs can grant different delegation
# rights to a principal, and because DelegateRights and SuperUser can
# themselves be delegated.

# The case where the "parent" delegated ACE is removed is handled in
# the embedded regression tests in lib/RT/ACE_Overlay.pm .


use RT;

use RT::Test tests => 98;

my ($u1, $u2, $g1, $g2, $g3, $pg1, $pg2, $ace, @groups, @users, @principals);
@groups = (\$g1, \$g2, \$g3, \$pg1, \$pg2);
@users = (\$u1, \$u2);
@principals = (@groups, @users);

my($ret, $msg);

$u1 = RT::User->new($RT::SystemUser);
( $ret, $msg ) = $u1->LoadOrCreateByEmail('delegtest1@example.com');
ok( $ret, "Load / Create test user 1: $msg" );
$u1->SetPrivileged(1);
$u2 = RT::User->new($RT::SystemUser);
( $ret, $msg ) = $u2->LoadOrCreateByEmail('delegtest2@example.com');
ok( $ret, "Load / Create test user 2: $msg" );
$u2->SetPrivileged(1);
$g1 = RT::Group->new($RT::SystemUser);
( $ret, $msg) = $g1->LoadUserDefinedGroup('dg1');
unless ($ret) {
    ( $ret, $msg ) = $g1->CreateUserDefinedGroup( Name => 'dg1' );
}
ok( $ret, "Load / Create test group 1: $msg" );
$g2 = RT::Group->new($RT::SystemUser);
( $ret, $msg) = $g2->LoadUserDefinedGroup('dg2');
unless ($ret) {
    ( $ret, $msg ) = $g2->CreateUserDefinedGroup( Name => 'dg2' );
}
ok( $ret, "Load / Create test group 2: $msg" );
$g3 = RT::Group->new($RT::SystemUser);
( $ret, $msg) = $g3->LoadUserDefinedGroup('dg3');
unless ($ret) {
    ( $ret, $msg ) = $g3->CreateUserDefinedGroup( Name => 'dg3' );
}
ok( $ret, "Load / Create test group 3: $msg" );
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
					  User => $u2->PrincipalId );
unless ($ret) {
    ( $ret, $msg ) = $pg2->CreatePersonalGroup( Name => 'dpg2',
						PrincipalId => $u2->PrincipalId );
}
ok( $ret, "Load / Create test personal group 2: $msg" );



# Basic case: u has global DelegateRights through g1 and ShowConfigTab
# through g2; then u is removed from g1.

clear_acls_and_groups();

( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg ) = $g2->PrincipalObj->GrantRight( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
ok(
    $u1->PrincipalObj->HasRight(
        Right  => 'DelegateRights',
        Object => $RT::System
    ),
    "test user 1 has DelegateRights after joining g1"
);
( $ret, $msg ) = $g2->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g2: $msg" );
ok(
    $u1->PrincipalObj->HasRight(
        Right  => 'ShowConfigTab',
        Object => $RT::System
    ),
    "test user 1 has ShowConfigTab after joining g2"
);

$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'ShowConfigTab',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
ok(
    $pg1->PrincipalObj->HasRight(
        Right  => 'ShowConfigTab',
        Object => $RT::System
    ),
    "Test personal group 1 has ShowConfigTab right after delegation"
);

( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok(
    not(
        $pg1->PrincipalObj->HasRight(
            Right  => 'ShowConfigTab',
            Object => $RT::System
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after user removed from g1"
);

# Basic case: u has global DelegateRights through g1 and ShowConfigTab
# through g2; then DelegateRights revoked from g1.

( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $g1->PrincipalObj->RevokeRight( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1: $msg" );
ok(
    not(
        $pg1->PrincipalObj->HasRight(
            Right  => 'ShowConfigTab',
            Object => $RT::System
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after DelegateRights revoked from g1"
);



# Corner case - restricted delegation: u has DelegateRights on pg1
# through g1 and AdminGroup on pg1 through g2; then DelegateRights
# revoked from g1.

clear_acls_and_groups();

( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					        Object => $pg1);
ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $g2->PrincipalObj->GrantRight( Right => 'AdminGroup',
					        Object => $pg1);
ok( $ret, "Grant AdminGroup on pg1 to g2: $msg" );
( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $g2->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g2: $msg" );
ok( $u1->PrincipalObj->HasRight(
        Right  => 'DelegateRights',
        Object => $pg1 ),
    "test user 1 has DelegateRights on pg1 after joining g1" );
ok( not( $u1->PrincipalObj->HasRight(
            Right  => 'DelegateRights',
            Object => $RT::System )),
    "Test personal group 1 lacks global DelegateRights after joining g1" );
$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'AdminGroup',
    Object        => $pg1,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
ok( $pg1->PrincipalObj->HasRight(
        Right  => 'AdminGroup',
        Object => $pg1 ),
    "Test personal group 1 has AdminGroup right on pg1 after delegation" );
( $ret, $msg ) = $g1->PrincipalObj->RevokeRight ( Right => 'DelegateRights',
						  Object => $pg1 );
ok( $ret, "Revoke DelegateRights on pg1 from g1: $msg" );
ok( not( $pg1->PrincipalObj->HasRight(
            Right  => 'AdminGroup',
            Object => $pg1 )),
    "Test personal group 1 lacks AdminGroup right on pg1 after DelegateRights revoked from g1" );
( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					        Object => $pg1);

# Corner case - restricted delegation: u has DelegateRights on pg1
# through g1 and AdminGroup on pg1 through g2; then u removed from g1.

ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
ok( $pg1->PrincipalObj->HasRight(
        Right  => 'AdminGroup',
        Object => $pg1 ),
    "Test personal group 1 has AdminGroup right on pg1 after delegation" );
( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( not( $pg1->PrincipalObj->HasRight(
            Right  => 'AdminGroup',
            Object => $pg1 )),
    "Test personal group 1 lacks AdminGroup right on pg1 after user removed from g1" );

clear_acls_and_groups();



# Corner case - multiple delegation rights: u has global
# DelegateRights directly and DelegateRights on pg1 through g1, and
# AdminGroup on pg1 through g2; then u removed from g1 (delegation
# should remain); then DelegateRights revoked from u (delegation
# should not remain).

( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					        Object => $pg1);
ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $g2->PrincipalObj->GrantRight( Right => 'AdminGroup',
					        Object => $pg1);
ok( $ret, "Grant AdminGroup on pg1 to g2: $msg" );
( $ret, $msg ) = $u1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					       Object => $RT::System);
ok( $ret, "Grant DelegateRights to user: $msg" );
( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $g2->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g2: $msg" );
$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'AdminGroup',
    Object        => $pg1,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( $pg1->PrincipalObj->HasRight(Right  => 'AdminGroup',
				Object => $pg1),
    "Test personal group 1 retains AdminGroup right on pg1 after user removed from g1" );
( $ret, $msg ) = $u1->PrincipalObj->RevokeRight( Right => 'DelegateRights',
						Object => $RT::System );
ok( not ($pg1->PrincipalObj->HasRight(Right  => 'AdminGroup',
				     Object => $pg1)),
    "Test personal group 1 lacks AdminGroup right on pg1 after DelegateRights revoked");

# Corner case - multiple delegation rights and selectivity: u has
# DelegateRights globally and on g2 directly and DelegateRights on pg1
# through g1, and AdminGroup on pg1 through g2; then global
# DelegateRights revoked from u (delegation should remain),
# DelegateRights on g2 revoked from u (delegation should remain), and
# u removed from g1 (delegation should not remain).

( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $u1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					       Object => $RT::System);
ok( $ret, "Grant DelegateRights to user: $msg" );
( $ret, $msg ) = $u1->PrincipalObj->GrantRight( Right => 'DelegateRights',
					       Object => $g2);
ok( $ret, "Grant DelegateRights on g2 to user: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
( $ret, $msg ) = $u1->PrincipalObj->RevokeRight( Right => 'DelegateRights',
						Object => $RT::System );
ok( $pg1->PrincipalObj->HasRight(Right  => 'AdminGroup',
				Object => $pg1),
    "Test personal group 1 retains AdminGroup right on pg1 after global DelegateRights revoked" );
( $ret, $msg ) = $u1->PrincipalObj->RevokeRight( Right => 'DelegateRights',
						Object => $g2 );
ok( $pg1->PrincipalObj->HasRight(Right  => 'AdminGroup',
				Object => $pg1),
    "Test personal group 1 retains AdminGroup right on pg1 after DelegateRights on g2 revoked" );
( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( not ($pg1->PrincipalObj->HasRight(Right  => 'AdminGroup',
				     Object => $pg1)),
    "Test personal group 1 lacks AdminGroup right on pg1 after user removed from g1");



# Corner case - indirect delegation rights: u has DelegateRights
# through g1 via g3, and ShowConfigTab via g2; then g3 removed from
# g1.

clear_acls_and_groups();

( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg ) = $g2->PrincipalObj->GrantRight( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->AddMember( $g3->PrincipalId );
ok( $ret, "Add g3 to g1: $msg" );
( $ret, $msg ) = $g3->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g3: $msg" );
( $ret, $msg ) = $g2->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g2: $msg" );

$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'ShowConfigTab',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );

( $ret, $msg ) = $g1->DeleteMember( $g3->PrincipalId );
ok( $ret, "Delete g3 from g1: $msg" );
ok( not ($pg1->PrincipalObj->HasRight(Right  => 'ShowConfigTab',
				     Object => $RT::System)),
	 "Test personal group 1 lacks ShowConfigTab right after g3 removed from g1");

# Corner case - indirect delegation rights: u has DelegateRights
# through g1 via g3, and ShowConfigTab via g2; then DelegateRights
# revoked from g1.

( $ret, $msg ) = $g1->AddMember( $g3->PrincipalId );
ok( $ret, "Add g3 to g1: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg ) = $g1->PrincipalObj->RevokeRight ( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1: $msg" );

ok( not ($pg1->PrincipalObj->HasRight(Right  => 'ShowConfigTab',
				     Object => $RT::System)),
	 "Test personal group 1 lacks ShowConfigTab right after DelegateRights revoked from g1");



# Corner case - delegation of DelegateRights: u1 has DelegateRights
# via g1 and delegates DelegateRights to pg1; u2 has DelegateRights
# via pg1 and ShowConfigTab via g2; then u1 removed from g1.

clear_acls_and_groups();

( $ret, $msg ) = $g1->PrincipalObj->GrantRight( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg ) = $g2->PrincipalObj->GrantRight( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add test user 1 to g1: $msg" );
$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'DelegateRights',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g1->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate DelegateRights to pg1: $msg" );

( $ret, $msg ) = $pg1->AddMember( $u2->PrincipalId );
ok( $ret, "Add test user 2 to pg1: $msg" );
( $ret, $msg ) = $g2->AddMember( $u2->PrincipalId );
ok( $ret, "Add test user 2 to g2: $msg" );
$ace = RT::ACE->new($u2);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'ShowConfigTab',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg2->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok( $pg2->PrincipalObj->HasRight(Right  => 'ShowConfigTab',
				 Object => $RT::System),
    "Test personal group 2 has ShowConfigTab right after delegation");
( $ret, $msg ) = $g1->DeleteMember( $u1->PrincipalId );
ok( $ret, "Delete u1 from g1: $msg" );
ok( not ($pg2->PrincipalObj->HasRight(Right  => 'ShowConfigTab',
				      Object => $RT::System)),
	 "Test personal group 2 lacks ShowConfigTab right after u1 removed from g1");

# Corner case - delegation of DelegateRights: u1 has DelegateRights
# via g1 and delegates DelegateRights to pg1; u2 has DelegateRights
# via pg1 and ShowConfigTab via g2; then DelegateRights revoked from
# g1.

( $ret, $msg ) = $g1->AddMember( $u1->PrincipalId );
ok( $ret, "Add u1 to g1: $msg" );
$ace = RT::ACE->new($u1);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'DelegateRights',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g1->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg1->PrincipalId );
ok( $ret, "Delegate DelegateRights to pg1: $msg" );
$ace = RT::ACE->new($u2);
( $ret, $msg ) = $ace->LoadByValues(
    RightName     => 'ShowConfigTab',
    Object        => $RT::System,
    PrincipalType => 'Group',
    PrincipalId   => $g2->PrincipalId
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->Delegate( PrincipalId => $pg2->PrincipalId );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

( $ret, $msg ) = $g1->PrincipalObj->RevokeRight ( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1: $msg" );
ok( not ($pg2->PrincipalObj->HasRight(Right  => 'ShowConfigTab',
				      Object => $RT::System)),
	 "Test personal group 2 lacks ShowConfigTab right after DelegateRights revoked from g1");




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
