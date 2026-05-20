
use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->db_is_valid;

{
    my $group = RT::Test->load_or_create_group('test', Members => [] );
    ok $group, "loaded or created a group";

    RT::Test->db_is_valid;
}

# G1 -> G2
{
    my $group1 = RT::Test->load_or_create_group( 'test1', Members => [] );
    ok $group1, "loaded or created a group";

    my $group2 = RT::Test->load_or_create_group( 'test2', Members => [ $group1 ]);
    ok $group2, "loaded or created a group";

    ok $group2->HasMember( $group1->id ), "has member";
    ok $group2->HasMemberRecursively( $group1->id ), "has member";

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do("DELETE FROM CachedGroupMembers");
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    ok !$group2->HasMemberRecursively( $group1->id ), "has no member, broken DB";

    my ($ecode, $res) = RT::Test->run_validator(resolve => 1);
    isnt($ecode, 0, 'non-zero exit code');

    ok $group2->HasMember( $group1->id ), "has member";
    ok $group2->HasMemberRecursively( $group1->id ), "has member";

    RT::Test->db_is_valid;
}

# G1 <- G2 <- G3 <- G4 <- G5
{
    my @groups;
    for (1..5) {
        my $child = @groups? $groups[-1]: undef;

        my $group = RT::Test->load_or_create_group( 'test'. $_, Members => [ $child? ($child): () ] );
        ok $group, "loaded or created a group";

        ok $group->HasMember( $child->id ), "has member"
            if $child;
        ok $group->HasMemberRecursively( $_->id ), "has member"
            foreach @groups;

        push @groups, $group;
    }

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do("DELETE FROM CachedGroupMembers");
    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    ok !$groups[1]->HasMemberRecursively( $groups[0]->id ), "has no member, broken DB";

    my ($ecode, $res) = RT::Test->run_validator(resolve => 1);
    isnt($ecode, 0, 'non-zero exit code');

    for ( my $i = 1; $i < @groups; $i++ ) {
        ok $groups[$i]->HasMember( $groups[$i-1]->id ), "has member";
        ok $groups[$i]->HasMemberRecursively( $groups[$_]->id ), "has member"
            foreach 0..$i-1;
    }

    RT::Test->db_is_valid;
}

# G1 <- (G2, G3, G4, G5)
{
    my @groups;
    for (2..5) {
        my $group = RT::Test->load_or_create_group( 'test'. $_, Members => [] );
        ok $group, "loaded or created a group";
        push @groups, $group;
    }

    my $parent = RT::Test->load_or_create_group( 'test1', Members => \@groups );
    ok $parent, "loaded or created a group";

    RT::Test->db_is_valid;
}

# G1 <- (G2, G3, G4) <- G5
{
    my $gchild = RT::Test->load_or_create_group( 'test5', Members => [] );
    ok $gchild, "loaded or created a group";
    
    my @groups;
    for (2..4) {
        my $group = RT::Test->load_or_create_group( 'test'. $_, Members => [ $gchild ] );
        ok $group, "loaded or created a group";
        push @groups, $group;
    }

    my $parent = RT::Test->load_or_create_group( 'test1', Members => \@groups );
    ok $parent, "loaded or created a group";

    RT::Test->db_is_valid;
}

# group without principal record and cgm records
# was causing infinite loop as principal was not created
{
    my $group = RT::Test->load_or_create_group('Test');
    ok $group && $group->id, 'loaded or created group';

    my $dbh = $group->_Handle->dbh;
    $dbh->do('DELETE FROM Principals WHERE id = ?', {RaiseError => 1}, $group->id);
    $dbh->do('DELETE FROM CachedGroupMembers WHERE GroupId = ?', {RaiseError => 1}, $group->id);
    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    my ($ecode, $res) = RT::Test->run_validator(resolve => 1, timeout => 30);
    isnt($ecode, 0, 'non-zero exit code');

    RT::Test->db_is_valid;
}

diag "CGM recurisve check for ticket role groups";
{
    my $ticket    = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket role group' );
    my $admincc   = $ticket->RoleGroup('AdminCc');
    my $delegates = RT::Test->load_or_create_group('delegates');
    my $core      = RT::Test->load_or_create_group('core team');
    my $alice     = RT::Test->load_or_create_user( Name => 'alice' );
    my $bob       = RT::Test->load_or_create_user( Name => 'bob' );

    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc' );
    ok( $delegates->AddMember( $core->PrincipalId ),    'Add core team to delegates' );
    ok( $delegates->AddMember( $bob->PrincipalId ),     'Add bob to delegates' );
    ok( $core->AddMember( $alice->PrincipalId ),        'Add alice to core team' );

    RT::Test->db_is_valid;
}

diag "User in both Privileged and Unprivileged groups";
{
    my $user = RT::Test->load_or_create_user( Name => 'test_both', Privileged => 0 );
    ok( $user && $user->id, 'Created unprivileged user' );
    ok( !$user->Privileged, 'User is unprivileged' );

    my ( $ok, $msg ) = RT->PrivilegedUsers->_AddMember( PrincipalId => $user->PrincipalId );
    ok( $ok, "Added user directly to Privileged group: $msg" );

    ok( RT->PrivilegedUsers->HasMember( $user->PrincipalObj ),   'User is now in Privileged' );
    ok( RT->UnprivilegedUsers->HasMember( $user->PrincipalObj ), 'User is still in Unprivileged' );

    my ( $ecode, $res ) = RT::Test->run_validator;
    isnt( $ecode, 0, 'Validator reports problem' );
    like( $res, qr/both Privileged and Unprivileged/, 'Validator identifies the issue' );

    ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'Non-zero exit code when resolving' );

    $user->Load( $user->id );
    ok( RT->PrivilegedUsers->HasMember( $user->PrincipalObj ),    'User remains in Privileged after resolve' );
    ok( !RT->UnprivilegedUsers->HasMember( $user->PrincipalObj ), 'User removed from Unprivileged after resolve' );

    RT::Test->db_is_valid;
}

diag "User in neither Privileged nor Unprivileged group";
{
    my $user = RT::Test->load_or_create_user( Name => 'test_neither', Privileged => 0 );
    ok( $user && $user->id, 'Created unprivileged user' );

    # Remove from Unprivileged bypassing SetPrivileged, to simulate broken state
    my $gm = RT::GroupMember->new( RT->SystemUser );
    $gm->LoadByCols( MemberId => $user->PrincipalId, GroupId => RT->UnprivilegedUsers->PrincipalId );
    $gm->Delete;

    ok( !RT->PrivilegedUsers->HasMember( $user->PrincipalObj ),   'User is not in Privileged' );
    ok( !RT->UnprivilegedUsers->HasMember( $user->PrincipalObj ), 'User is not in Unprivileged' );

    my ( $ecode, $res ) = RT::Test->run_validator;
    isnt( $ecode, 0, 'Validator reports problem' );
    like( $res, qr/neither Privileged nor Unprivileged/, 'Validator identifies the issue' );

    ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'Non-zero exit code when resolving' );

    $user->Load( $user->id );
    ok( !RT->PrivilegedUsers->HasMember( $user->PrincipalObj ),  'User is not in Privileged after resolve' );
    ok( RT->UnprivilegedUsers->HasMember( $user->PrincipalObj ), 'User added to Unprivileged after resolve' );

    RT::Test->db_is_valid;
}

done_testing;
