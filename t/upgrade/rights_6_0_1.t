use strict;
use warnings;

use RT::Test tests => undef;

# Exercises the 6.0.1 upgrade step in etc/upgrade/6.0.1/content that renames
# the old saved-search and dashboard rights to their new names.
#
# The interesting case is a right that is granted directly to both a group and
# one of its subgroups. The migration walks the ACL in an unspecified order
# (its query has no ORDER BY); when the parent's ACE is renamed first, the
# subgroup inherits the new right through group membership. The original code
# tested for the new right with HasRight, which honors that inheritance, and so
# deleted the subgroup's own direct grant instead of renaming it. The fix tests
# for a *direct* ACE only, so both grants survive.
#
# We seed the ACL directly (below) because the old right names are no longer
# registered, so GrantRight would reject them -- the same reason the pre-upgrade
# state can only exist on a database created by an older RT.

my $system = RT->System;

# ---------------------------------------------------------------------------
# Insert a pre-upgrade ACE carrying an old (now-unregistered) right name,
# bypassing RT::ACE::Create's right-name validation. Insertion order matters:
# to trigger the pre-fix bug regardless of the query plan, parent ACEs are
# seeded before their subgroups' ACEs (lower row id), and parent groups are
# created before subgroups (lower PrincipalId) -- covering both a rowid-order
# and an index-order scan.
sub seed_ace {
    my %args = @_;
    my $object = $args{Object};
    my $type   = $args{PrincipalType} || 'Group';
    my $ace    = RT::ACE->new( RT->SystemUser );
    my ( $id, $msg ) = $ace->DBIx::SearchBuilder::Record::Create(
        PrincipalId   => $args{Principal}->PrincipalId,
        PrincipalType => $type,
        RightName     => $args{Right},
        ObjectType    => ref($object) || 'RT::System',
        ObjectId      => $object->id,
    );
    ok( $id, "Seeded old right $args{Right} for $type @{[ $args{Principal}->Name ]} on @{[ ref $object ]} #@{[ $object->id ]}" )
        or diag $msg;
    return $id;
}

# Count only DIRECT ACEs (a real row in the ACL table) for this principal,
# right, and object -- not rights that would be inherited via group membership.
sub direct_ace_count {
    my %args = @_;
    my $acl  = RT::ACL->new( RT->SystemUser );
    $acl->LimitToObject( $args{Object} );
    $acl->Limit( FIELD => 'RightName',   VALUE => $args{Right} );
    $acl->Limit( FIELD => 'PrincipalId', VALUE => $args{Principal}->PrincipalId );
    return $acl->Count;
}

# ---------------------------------------------------------------------------
# Groups. Parents are created before their subgroups so the parent principal
# sorts first under the ACL index.
diag "Setting up groups";

my %group;
for my $name (
    qw/
    S1-SysSearch  S2-SelfSearch
    S3-Parent     S3-Child
    S4-Create     S5-EditSys
    S6-EditGroup  S6-Target
    S7-MultiDash
    S8-DashParent S8-DashChild S8-DashTarget
    S9-Parent     S9-Child
    S10-Group
    /
    )
{
    $group{$name} = RT::Test->load_or_create_group($name);
    ok( $group{$name}->id, "Created group $name" );
}

# A user who is a member of S10-Group; both the user and the group hold the
# same old right directly (Scenario 10).
my $s10_user = RT::Test->load_or_create_user( Name => 'S10-user' );
ok( $s10_user->id, 'Created user S10-user' );

# Subgroup memberships (child is a member of parent).
for my $pair ( [ 'S3-Parent', 'S3-Child' ], [ 'S8-DashParent', 'S8-DashChild' ], [ 'S9-Parent', 'S9-Child' ] ) {
    my ( $parent, $child ) = @$pair;
    my ( $ok, $msg ) = $group{$parent}->AddMember( $group{$child}->PrincipalId );
    ok( $ok, "$child is a member of $parent" ) or diag $msg;
}
{
    my ( $ok, $msg ) = $group{'S10-Group'}->AddMember( $s10_user->PrincipalId );
    ok( $ok, 'S10-user is a member of S10-Group' ) or diag $msg;
}

# ---------------------------------------------------------------------------
# Seed the old-name ACEs. Order within each parent/child scenario is
# deliberate: parent first.
diag "Seeding pre-upgrade ACEs with old right names";

# Scenario 1: ShowSavedSearches on RT::System -> SeeSavedSearch
seed_ace( Principal => $group{'S1-SysSearch'}, Right => 'ShowSavedSearches', Object => $system );

# Scenario 2: ShowSavedSearches on a group -> SeeGroupSavedSearch
seed_ace( Principal => $group{'S2-SelfSearch'}, Right => 'ShowSavedSearches', Object => $group{'S2-SelfSearch'} );

# Scenario 3 (inheritance): parent + subgroup both hold ShowSavedSearches on S3-Child.
seed_ace( Principal => $group{'S3-Parent'}, Right => 'ShowSavedSearches', Object => $group{'S3-Child'} );
seed_ace( Principal => $group{'S3-Child'},  Right => 'ShowSavedSearches', Object => $group{'S3-Child'} );

# Scenario 4: CreateSavedSearch -> AdminSavedSearch
seed_ace( Principal => $group{'S4-Create'}, Right => 'CreateSavedSearch', Object => $system );

# Scenario 5: EditSavedSearches on RT::System -> AdminSavedSearch
seed_ace( Principal => $group{'S5-EditSys'}, Right => 'EditSavedSearches', Object => $system );

# Scenario 6: EditSavedSearches on a group -> AdminGroupSavedSearch
seed_ace( Principal => $group{'S6-EditGroup'}, Right => 'EditSavedSearches', Object => $group{'S6-Target'} );

# Scenario 7 (dedup): three old system dashboard rights all map to AdminDashboard.
seed_ace( Principal => $group{'S7-MultiDash'}, Right => 'CreateDashboard', Object => $system );
seed_ace( Principal => $group{'S7-MultiDash'}, Right => 'ModifyDashboard', Object => $system );
seed_ace( Principal => $group{'S7-MultiDash'}, Right => 'DeleteDashboard', Object => $system );

# Scenario 8 (inheritance): parent + subgroup both hold CreateGroupDashboard on S8-DashTarget.
seed_ace( Principal => $group{'S8-DashParent'}, Right => 'CreateGroupDashboard', Object => $group{'S8-DashTarget'} );
seed_ace( Principal => $group{'S8-DashChild'},  Right => 'CreateGroupDashboard', Object => $group{'S8-DashTarget'} );

# Scenario 9 (inheritance): parent and subgroup hold two different old rights that both
# map to AdminSavedSearch. CreateSavedSearch sorts before EditSavedSearches, so
# the parent is migrated first under an index scan; seeding it first covers a
# rowid scan too.
seed_ace( Principal => $group{'S9-Parent'}, Right => 'CreateSavedSearch', Object => $system );
seed_ace( Principal => $group{'S9-Child'},  Right => 'EditSavedSearches', Object => $system );

# Scenario 10 (inheritance): a user holds ShowSavedSearches directly AND inherits it
# from S10-Group. Seed the group's ACE first; the group is also migrated first
# under an index scan ('Group' sorts before 'User' as a PrincipalType), so the
# user inherits SeeSavedSearch and the pre-fix code deletes the user's own ACE.
seed_ace( Principal => $group{'S10-Group'}, Right => 'ShowSavedSearches', Object => $system );
seed_ace( Principal => $s10_user, PrincipalType => 'User', Right => 'ShowSavedSearches', Object => $system );

# ---------------------------------------------------------------------------
# Run the real upgrade step and clear the ACL cache so HasRight reflects the
# post-migration table.
my $content = "$RT::EtcPath/upgrade/6.0.1/content";
ok( -e $content, "Found upgrade content file at $content" );

diag "Running the 6.0.1 rights migration";
my ( $rv, $msg ) = RT->DatabaseHandle->InsertData( $content, undef, disconnect_after => 0 );
ok( $rv, "Ran upgrade step: $content" ) or diag "Error: $msg";

RT::Principal->InvalidateACLCache;

# ---------------------------------------------------------------------------
diag "Scenario 1: ShowSavedSearches on RT::System -> SeeSavedSearch";
is( direct_ace_count( Principal => $group{'S1-SysSearch'}, Right => 'SeeSavedSearch', Object => $system ),
    1, 'S1-SysSearch has a direct SeeSavedSearch ACE' );
ok( $group{'S1-SysSearch'}->PrincipalObj->HasRight( Right => 'SeeSavedSearch', Object => $system ),
    'S1-SysSearch effectively has SeeSavedSearch' );

diag "Scenario 2: ShowSavedSearches on a group -> SeeGroupSavedSearch";
is( direct_ace_count( Principal => $group{'S2-SelfSearch'}, Right => 'SeeGroupSavedSearch', Object => $group{'S2-SelfSearch'} ),
    1, 'S2-SelfSearch has a direct SeeGroupSavedSearch ACE' );

diag "Scenario 3 (inheritance): subgroup keeps its own direct grant";
is( direct_ace_count( Principal => $group{'S3-Parent'}, Right => 'SeeGroupSavedSearch', Object => $group{'S3-Child'} ),
    1, 'S3-Parent has a direct SeeGroupSavedSearch ACE' );
is( direct_ace_count( Principal => $group{'S3-Child'}, Right => 'SeeGroupSavedSearch', Object => $group{'S3-Child'} ),
    1, 'S3-Child kept its own direct SeeGroupSavedSearch ACE (not deleted by inheritance)' );

diag "Scenario 4: CreateSavedSearch -> AdminSavedSearch";
is( direct_ace_count( Principal => $group{'S4-Create'}, Right => 'AdminSavedSearch', Object => $system ),
    1, 'S4-Create has a direct AdminSavedSearch ACE' );

diag "Scenario 5: EditSavedSearches on RT::System -> AdminSavedSearch";
is( direct_ace_count( Principal => $group{'S5-EditSys'}, Right => 'AdminSavedSearch', Object => $system ),
    1, 'S5-EditSys has a direct AdminSavedSearch ACE' );

diag "Scenario 6: EditSavedSearches on a group -> AdminGroupSavedSearch";
is( direct_ace_count( Principal => $group{'S6-EditGroup'}, Right => 'AdminGroupSavedSearch', Object => $group{'S6-Target'} ),
    1, 'S6-EditGroup has a direct AdminGroupSavedSearch ACE' );

diag "Scenario 7 (dedup): three dashboard rights collapse to one AdminDashboard";
is( direct_ace_count( Principal => $group{'S7-MultiDash'}, Right => 'AdminDashboard', Object => $system ),
    1, 'S7-MultiDash has exactly one direct AdminDashboard ACE' );

diag "Scenario 8 (inheritance): subgroup keeps its own direct group-dashboard grant";
is( direct_ace_count( Principal => $group{'S8-DashParent'}, Right => 'AdminGroupDashboard', Object => $group{'S8-DashTarget'} ),
    1, 'S8-DashParent has a direct AdminGroupDashboard ACE' );
is( direct_ace_count( Principal => $group{'S8-DashChild'}, Right => 'AdminGroupDashboard', Object => $group{'S8-DashTarget'} ),
    1, 'S8-DashChild kept its own direct AdminGroupDashboard ACE (not deleted by inheritance)' );

diag "Scenario 9 (inheritance): converging rights across parent/subgroup both survive";
is( direct_ace_count( Principal => $group{'S9-Parent'}, Right => 'AdminSavedSearch', Object => $system ),
    1, 'S9-Parent has a direct AdminSavedSearch ACE' );
is( direct_ace_count( Principal => $group{'S9-Child'}, Right => 'AdminSavedSearch', Object => $system ),
    1, 'S9-Child kept its own direct AdminSavedSearch ACE (not deleted by inheritance)' );

diag "Scenario 10 (inheritance): user keeps its own direct grant despite inheriting from a group";
is( direct_ace_count( Principal => $group{'S10-Group'}, Right => 'SeeSavedSearch', Object => $system ),
    1, 'S10-Group has a direct SeeSavedSearch ACE' );
is( direct_ace_count( Principal => $s10_user, Right => 'SeeSavedSearch', Object => $system ),
    1, 'S10-user kept its own direct SeeSavedSearch ACE (not deleted by group inheritance)' );
ok( $s10_user->PrincipalObj->HasRight( Right => 'SeeSavedSearch', Object => $system ),
    'S10-user effectively has SeeSavedSearch' );

# ---------------------------------------------------------------------------
diag "No old right names remain in the ACL table";
my @old = qw/
    ShowSavedSearches CreateSavedSearch EditSavedSearches
    CreateDashboard   ModifyDashboard   DeleteDashboard
    CreateGroupDashboard ModifyGroupDashboard DeleteGroupDashboard
    /;
my $leftover = RT::ACL->new( RT->SystemUser );
$leftover->Limit( FIELD => 'RightName', VALUE => \@old, OPERATOR => 'IN' );
is( $leftover->Count, 0, 'No old right names remain in the ACL table' );

done_testing();
