#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 60;

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

my $validator_path = "$RT::SbinPath/rt-validator";
sub run_validator {
    my %args = (check => 1, resolve => 0, force => 1, @_ );

    my $cmd = $validator_path;
    die "Couldn't find $cmd command" unless -f $cmd;

    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= ' 2>&1';

    require IPC::Open2;
    my ($child_out, $child_in);
    my $pid = IPC::Open2::open2($child_out, $child_in, $cmd);
    close $child_in;

    my $result = do { local $/; <$child_out> };
    close $child_out;
    waitpid $pid, 0;

    DBIx::SearchBuilder::Record::Cachable->FlushCache
        if $args{'resolve'};

    return ($?, $result);
}

{
    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
}

{
    my $group = load_or_create_group('test', Members => [] );
    ok $group, "loaded or created a group";

    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
}

# G1 -> G2
{
    my $group1 = load_or_create_group( 'test1', Members => [] );
    ok $group1, "loaded or created a group";

    my $group2 = load_or_create_group( 'test2', Members => [ $group1 ]);
    ok $group2, "loaded or created a group";

    ok $group2->HasMember( $group1->id ), "has member";
    ok $group2->HasMemberRecursively( $group1->id ), "has member";

    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';

    $RT::Handle->dbh->do("DELETE FROM CachedGroupMembers");
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    ok !$group2->HasMemberRecursively( $group1->id ), "has no member, broken DB";

    ($ecode, $res) = run_validator(resolve => 1);

    ok $group2->HasMember( $group1->id ), "has member";
    ok $group2->HasMemberRecursively( $group1->id ), "has member";

    ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
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

    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';

    $RT::Handle->dbh->do("DELETE FROM CachedGroupMembers");
    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    ok !$groups[1]->HasMemberRecursively( $groups[0]->id ), "has no member, broken DB";

    ($ecode, $res) = run_validator(resolve => 1);

    for ( my $i = 1; $i < @groups; $i++ ) {
        ok $groups[$i]->HasMember( $groups[$i-1]->id ), "has member";
        ok $groups[$i]->HasMemberRecursively( $groups[$_]->id ), "has member"
            foreach 0..$i-1;
    }

    ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
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

    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
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

    my ($ecode, $res) = run_validator();
    is $res, '', 'empty result';
}

