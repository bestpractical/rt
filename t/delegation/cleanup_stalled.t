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

use RT::Test;
use Test::More;
plan tests => 98;

use RT;

my ($u1,  $u2,  $g1,     $g2,    $g3, $pg1,
    $pg2, $ace, @groups, @users, @principals
);
@groups = ( \$g1, \$g2, \$g3, \$pg1, \$pg2 );
@users = ( \$u1, \$u2 );
@principals = ( @groups, @users );

my ( $ret, $msg );

$u1 = RT::Model::User->new( current_user => RT->system_user );
( $ret, $msg ) = $u1->load_or_create_by_email('delegtest1@example.com');
ok( $ret, "Load / Create test user 1: $msg" );
$u1->set_privileged(1);
$u2 = RT::Model::User->new( current_user => RT->system_user );
( $ret, $msg ) = $u2->load_or_create_by_email('delegtest2@example.com');
ok( $ret, "Load / Create test user 2: $msg" );
$u2->set_privileged(1);
$g1 = RT::Model::Group->new( current_user => RT->system_user );
( $ret, $msg ) = $g1->load_user_defined_group('dg1');

unless ($ret) {
    ( $ret, $msg ) = $g1->create_user_defined_group( name => 'dg1' );
}
ok( $ret, "Load / Create test group 1: $msg" );
$g2 = RT::Model::Group->new( current_user => RT->system_user );
( $ret, $msg ) = $g2->load_user_defined_group('dg2');
unless ($ret) {
    ( $ret, $msg ) = $g2->create_user_defined_group( name => 'dg2' );
}
ok( $ret, "Load / Create test group 2: $msg" );
$g3 = RT::Model::Group->new( current_user => RT->system_user );
( $ret, $msg ) = $g3->load_user_defined_group('dg3');
unless ($ret) {
    ( $ret, $msg ) = $g3->create_user_defined_group( name => 'dg3' );
}
ok( $ret, "Load / Create test group 3: $msg" );
$pg1 = RT::Model::Group->new( current_user => RT->system_user );
( $ret, $msg ) = $pg1->load_personal_group(
    name => 'dpg1',
    User => $u1->principal_id
);
unless ($ret) {
    ( $ret, $msg ) = $pg1->create_personal_group(
        name         => 'dpg1',
        principal_id => $u1->principal_id
    );
}
ok( $ret, "Load / Create test personal group 1: $msg" );
$pg2 = RT::Model::Group->new( current_user => RT->system_user );
( $ret, $msg ) = $pg2->load_personal_group(
    name => 'dpg2',
    User => $u2->principal_id
);
unless ($ret) {
    ( $ret, $msg ) = $pg2->create_personal_group(
        name         => 'dpg2',
        principal_id => $u2->principal_id
    );
}
ok( $ret, "Load / Create test personal group 2: $msg" );

# Basic case: u has global DelegateRights through g1 and ShowConfigTab
# through g2; then u is removed from g1.

clear_acls_and_groups();

( $ret, $msg )
    = $g1->principal_object->grant_right( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg )
    = $g2->principal_object->grant_right( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
ok( $u1->principal_object->has_right(
        Right  => 'DelegateRights',
        Object => RT->system
    ),
    "test user 1 has DelegateRights after joining g1"
);
( $ret, $msg ) = $g2->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g2: $msg" );
ok( $u1->principal_object->has_right(
        Right  => 'ShowConfigTab',
        Object => RT->system
    ),
    "test user 1 has ShowConfigTab after joining g2"
);

$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );
( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'ShowConfigTab',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after user removed from g1"
);
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegated ShowConfigTab to pg1: $msg" );

ok( $pg1->principal_object->has_right(
        Right  => 'ShowConfigTab',
        Object => RT->system
    ),
    "Test personal group 1 has ShowConfigTab right after delegation"
);

( $ret, $msg ) = $g1->delete_member( $u1->principal_id );

ok( $ret, "Delete test user 1 from g1: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after user removed from g1"
);

# Basic case: u has global DelegateRights through g1 and ShowConfigTab
# through g2; then DelegateRights revoked from g1.

( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg )
    = $g1->principal_object->revoke_right( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1 (" . $g1->id . "): $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after DelegateRights revoked from g1"
);

# Corner case - restricted delegation: u has DelegateRights on pg1
# through g1 and AdminGroup on pg1 through g2; then DelegateRights
# revoked from g1.

clear_acls_and_groups();

( $ret, $msg ) = $g1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => $pg1
);
ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $g2->principal_object->grant_right(
    Right  => 'AdminGroup',
    Object => $pg1
);
ok( $ret, "Grant AdminGroup on pg1 to g2: $msg" );
( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $g2->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g2: $msg" );
ok( $u1->principal_object->has_right(
        Right  => 'DelegateRights',
        Object => $pg1
    ),
    "test user 1 has DelegateRights on pg1 after joining g1"
);
ok( not($u1->principal_object->has_right(
            Right  => 'DelegateRights',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks global DelegateRights after joining g1"
);
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );
( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'AdminGroup',
    Object         => $pg1,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
ok( $pg1->principal_object->has_right(
        Right  => 'AdminGroup',
        Object => $pg1
    ),
    "Test personal group 1 has AdminGroup right on pg1 after delegation"
);
( $ret, $msg ) = $g1->principal_object->revoke_right(
    Right  => 'DelegateRights',
    Object => $pg1
);
ok( $ret, "Revoke DelegateRights on pg1 from g1: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'AdminGroup',
            Object => $pg1
        )
    ),
    "Test personal group 1 lacks AdminGroup right on pg1 after DelegateRights revoked from g1"
);
( $ret, $msg ) = $g1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => $pg1
);

# Corner case - restricted delegation: u has DelegateRights on pg1
# through g1 and AdminGroup on pg1 through g2; then u removed from g1.

ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
ok( $pg1->principal_object->has_right(
        Right  => 'AdminGroup',
        Object => $pg1
    ),
    "Test personal group 1 has AdminGroup right on pg1 after delegation"
);
( $ret, $msg ) = $g1->delete_member( $u1->principal_id );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'AdminGroup',
            Object => $pg1
        )
    ),
    "Test personal group 1 lacks AdminGroup right on pg1 after user removed from g1"
);

clear_acls_and_groups();

# Corner case - multiple delegation rights: u has global
# DelegateRights directly and DelegateRights on pg1 through g1, and
# AdminGroup on pg1 through g2; then u removed from g1 (delegation
# should remain); then DelegateRights revoked from u (delegation
# should not remain).

( $ret, $msg ) = $g1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => $pg1
);
ok( $ret, "Grant DelegateRights on pg1 to g1: $msg" );
( $ret, $msg ) = $g2->principal_object->grant_right(
    Right  => 'AdminGroup',
    Object => $pg1
);
ok( $ret, "Grant AdminGroup on pg1 to g2: $msg" );
( $ret, $msg ) = $u1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => RT->system
);
ok( $ret, "Grant DelegateRights to user: $msg" );
( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $g2->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g2: $msg" );
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );

( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'AdminGroup',
    Object         => $pg1,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
( $ret, $msg ) = $g1->delete_member( $u1->principal_id );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( $pg1->principal_object->has_right(
        Right  => 'AdminGroup',
        Object => $pg1
    ),
    "Test personal group 1 retains AdminGroup right on pg1 after user removed from g1"
);
( $ret, $msg ) = $u1->principal_object->revoke_right(
    Right  => 'DelegateRights',
    Object => RT->system
);
ok( not($pg1->principal_object->has_right(
            Right  => 'AdminGroup',
            Object => $pg1
        )
    ),
    "Test personal group 1 lacks AdminGroup right on pg1 after DelegateRights revoked"
);

# Corner case - multiple delegation rights and selectivity: u has
# DelegateRights globally and on g2 directly and DelegateRights on pg1
# through g1, and AdminGroup on pg1 through g2; then global
# DelegateRights revoked from u (delegation should remain),
# DelegateRights on g2 revoked from u (delegation should remain), and
# u removed from g1 (delegation should not remain).

( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
( $ret, $msg ) = $u1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => RT->system
);
ok( $ret, "Grant DelegateRights to user: $msg" );
( $ret, $msg ) = $u1->principal_object->grant_right(
    Right  => 'DelegateRights',
    Object => $g2
);
ok( $ret, "Grant DelegateRights on g2 to user: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate AdminGroup on pg1 to pg1: $msg" );
( $ret, $msg ) = $u1->principal_object->revoke_right(
    Right  => 'DelegateRights',
    Object => RT->system
);
ok( $pg1->principal_object->has_right(
        Right  => 'AdminGroup',
        Object => $pg1
    ),
    "Test personal group 1 retains AdminGroup right on pg1 after global DelegateRights revoked"
);
( $ret, $msg ) = $u1->principal_object->revoke_right(
    Right  => 'DelegateRights',
    Object => $g2
);
ok( $pg1->principal_object->has_right(
        Right  => 'AdminGroup',
        Object => $pg1
    ),
    "Test personal group 1 retains AdminGroup right on pg1 after DelegateRights on g2 revoked"
);
( $ret, $msg ) = $g1->delete_member( $u1->principal_id );
ok( $ret, "Delete test user 1 from g1: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'AdminGroup',
            Object => $pg1
        )
    ),
    "Test personal group 1 lacks AdminGroup right on pg1 after user removed from g1"
);

# Corner case - indirect delegation rights: u has DelegateRights
# through g1 via g3, and ShowConfigTab via g2; then g3 removed from
# g1.

clear_acls_and_groups();

( $ret, $msg )
    = $g1->principal_object->grant_right( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg )
    = $g2->principal_object->grant_right( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->add_member( $g3->principal_id );
ok( $ret, "Add g3 to g1: $msg" );
( $ret, $msg ) = $g3->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g3: $msg" );
( $ret, $msg ) = $g2->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g2: $msg" );

$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );

( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'ShowConfigTab',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );

( $ret, $msg ) = $g1->delete_member( $g3->principal_id );
ok( $ret, "Delete g3 from g1: $msg" );
ok( not($pg1->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after g3 removed from g1"
);

# Corner case - indirect delegation rights: u has DelegateRights
# through g1 via g3, and ShowConfigTab via g2; then DelegateRights
# revoked from g1.

( $ret, $msg ) = $g1->add_member( $g3->principal_id );
ok( $ret, "Add g3 to g1: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg1: $msg" );
( $ret, $msg )
    = $g1->principal_object->revoke_right( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1: $msg" );

ok( not($pg1->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 1 lacks ShowConfigTab right after DelegateRights revoked from g1"
);

# Corner case - delegation of DelegateRights: u1 has DelegateRights
# via g1 and delegates DelegateRights to pg1; u2 has DelegateRights
# via pg1 and ShowConfigTab via g2; then u1 removed from g1.

clear_acls_and_groups();

( $ret, $msg )
    = $g1->principal_object->grant_right( Right => 'DelegateRights' );
ok( $ret, "Grant DelegateRights to g1: $msg" );
( $ret, $msg )
    = $g2->principal_object->grant_right( Right => 'ShowConfigTab' );
ok( $ret, "Grant ShowConfigTab to g2: $msg" );
( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add test user 1 to g1: $msg" );
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );

( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'DelegateRights',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g1->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate DelegateRights to pg1: $msg" );

( $ret, $msg ) = $pg1->add_member( $u2->principal_id );
ok( $ret, "Add test user 2 to pg1: $msg" );
( $ret, $msg ) = $g2->add_member( $u2->principal_id );
ok( $ret, "Add test user 2 to g2: $msg" );
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u2->id ) );

( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'ShowConfigTab',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg2->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

ok( $pg2->principal_object->has_right(
        Right  => 'ShowConfigTab',
        Object => RT->system
    ),
    "Test personal group 2 has ShowConfigTab right after delegation"
);
( $ret, $msg ) = $g1->delete_member( $u1->principal_id );
ok( $ret, "Delete u1 from g1: $msg" );
ok( not($pg2->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 2 lacks ShowConfigTab right after u1 removed from g1"
);

# Corner case - delegation of DelegateRights: u1 has DelegateRights
# via g1 and delegates DelegateRights to pg1; u2 has DelegateRights
# via pg1 and ShowConfigTab via g2; then DelegateRights revoked from
# g1.

( $ret, $msg ) = $g1->add_member( $u1->principal_id );
ok( $ret, "Add u1 to g1: $msg" );
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u1->id ) );

( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'DelegateRights',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g1->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg1->principal_id );
ok( $ret, "Delegate DelegateRights to pg1: $msg" );
$ace = RT::Model::ACE->new(
    current_user => RT::CurrentUser->new( id => $u2 ) );
( $ret, $msg ) = $ace->load_by_values(
    right_name     => 'ShowConfigTab',
    Object         => RT->system,
    principal_type => 'Group',
    principal_id   => $g2->principal_id
);
ok( $ret, "Look up ACE to be delegated: $msg" );
( $ret, $msg ) = $ace->delegate( principal_id => $pg2->principal_id );
ok( $ret, "Delegate ShowConfigTab to pg2: $msg" );

( $ret, $msg )
    = $g1->principal_object->revoke_right( Right => 'DelegateRights' );
ok( $ret, "Revoke DelegateRights from g1: $msg" );
ok( not($pg2->principal_object->has_right(
            Right  => 'ShowConfigTab',
            Object => RT->system
        )
    ),
    "Test personal group 2 lacks ShowConfigTab right after DelegateRights revoked from g1"
);

#######

sub clear_acls_and_groups {

    # Revoke all rights granted to our cast
    my $acl
        = RT::Model::ACECollection->new( current_user => RT->system_user );
    foreach (@principals) {
        $acl->limit_to_principal(
            Type => $$_->principal_object->principal_type,
            id   => $$_->principal_object->id
        );
    }
    while ( my $ace = $acl->next() ) {
        $ace->delete();
    }

    # Remove all group memberships
    my $members = RT::Model::GroupMemberCollection->new(
        current_user => RT->system_user );
    foreach (@groups) {
        $members->limit_to_members_of_group( $$_->principal_id );
    }
    while ( my $member = $members->next() ) {
        $member->delete();
    }

    $acl->redo_search();
    is( $acl->count(), 0,
        "All principals have no rights after clearing ACLs" );
    $members->redo_search();
    is( $members->count(), 0,
        "All groups have no members after clearing groups" );
}
