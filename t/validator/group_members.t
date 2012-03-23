
use strict;
use warnings;

use RT::Test tests => 62;

sub load_or_create_group {
    my $name = shift;
    my %args = (@_);

    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup( $name );
    unless ( $group->id ) {
        my ($id, $msg) = $group->CreateUserDefinedGroup(
            Name => $name,
        );
        die "$msg" unless $id;
    }

    if ( $args{Members} ) {
        my $cur = $group->MembersObj;
        while ( my $entry = $cur->Next ) {
            my ($status, $msg) = $entry->Delete;
            die "$msg" unless $status;
        }

        foreach my $new ( @{ $args{Members} } ) {
            my ($status, $msg) = $group->AddMember(
                ref($new)? $new->id : $new,
            );
            die "$msg" unless $status;
        }
    }
    
    return $group;
}

RT::Test->db_is_valid;

{
    my $group = load_or_create_group('test', Members => [] );
    ok $group, "loaded or created a group";

    RT::Test->db_is_valid;
}

# G1 -> G2
{
    my $group1 = load_or_create_group( 'test1', Members => [] );
    ok $group1, "loaded or created a group";

    my $group2 = load_or_create_group( 'test2', Members => [ $group1 ]);
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

        my $group = load_or_create_group( 'test'. $_, Members => [ $child? ($child): () ] );
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
        ok $groups[$i]->HasMember( $groups[$i-1]->id ),
            "G #". $groups[$i]->id ." has member #". $groups[$i-1]->id;
        ok $groups[$i]->HasMemberRecursively( $groups[$_]->id ),
            "G #". $groups[$i]->id ." has member #". $groups[$_]->id
            foreach 0..$i-1;
    }

    RT::Test->db_is_valid;
}

# G1 <- (G2, G3, G4, G5)
{
    my @groups;
    for (2..5) {
        my $group = load_or_create_group( 'test'. $_, Members => [] );
        ok $group, "loaded or created a group";
        push @groups, $group;
    }

    my $parent = load_or_create_group( 'test1', Members => \@groups );
    ok $parent, "loaded or created a group";

    RT::Test->db_is_valid;
}

# G1 <- (G2, G3, G4) <- G5
{
    my $gchild = load_or_create_group( 'test5', Members => [] );
    ok $gchild, "loaded or created a group";
    
    my @groups;
    for (2..4) {
        my $group = load_or_create_group( 'test'. $_, Members => [ $gchild ] );
        ok $group, "loaded or created a group";
        push @groups, $group;
    }

    my $parent = load_or_create_group( 'test1', Members => \@groups );
    ok $parent, "loaded or created a group";

    RT::Test->db_is_valid;
}

