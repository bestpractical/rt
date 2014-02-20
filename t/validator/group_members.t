
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

done_testing;
