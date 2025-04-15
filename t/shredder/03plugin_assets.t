
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 49;
my $test = "RT::Test::Shredder";

use_ok('RT::Shredder');

use_ok('RT::Shredder::Plugin::Assets');
{
    my $plugin = RT::Shredder::Plugin::Assets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Assets');

    is(lc $plugin->Type, 'search', 'correct type');
}

$test->create_savepoint('clean');
use_ok('RT::Asset');
use_ok('RT::Assets');

{ # create parent and child and check functionality of 'with_linked' arg
    my $parent = RT::Asset->new( RT->SystemUser );
    my ($pid) = $parent->Create( Name => 'parent', Catalog => 1 );
    ok( $pid, "created new asset" );
    my $child = RT::Asset->new( RT->SystemUser );
    my ($cid) = $child->Create( Name => 'child', Catalog => 1, MemberOf => "asset:$pid" );
    ok( $cid, "created new asset" );

    my $plugin = RT::Shredder::Plugin::Assets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Assets');

    my ($status, $msg, @objs);
    ($status, $msg) = $plugin->TestArgs( query => 'Name = "parent"' );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 1, "only one object in result set");
    is($objs[0]->id, $pid, "parent is in result set");

    ($status, $msg) = $plugin->TestArgs( query => 'Name = "parent"', with_linked => 1 );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    my %has = map { $_->id => 1 } @objs;
    is(scalar @objs, 2, "two objects in the result set");
    ok($has{$pid}, "parent is in the result set");
    ok($has{$cid}, "child is in the result set");

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;
    $test->db_is_valid;
}
cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{ # create parent and child and link them reqursively to check that we don't hang
    my $parent = RT::Asset->new( RT->SystemUser );
    my ($pid) = $parent->Create( Name => 'parent', Catalog => 1 );
    ok( $pid, "created new asset" );

    my $child = RT::Asset->new( RT->SystemUser );
    my ($cid) = $child->Create( Name => 'child', Catalog => 1, MemberOf => "asset:$pid" );
    ok( $cid, "created new asset" );

    my ($status, $msg) = $child->AddLink( Target => "asset:$pid", Type => 'DependsOn' );
    ok($status, "added reqursive link") or diag "error: $msg";

    my $plugin = RT::Shredder::Plugin::Assets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Assets');

    my (@objs);
    ($status, $msg) = $plugin->TestArgs( query => 'Name = "parent"' );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 1, "only one object in result set");
    is($objs[0]->id, $pid, "parent is in result set");

    ($status, $msg) = $plugin->TestArgs( query => 'Name = "parent"', with_linked => 1 );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 2, "two objects in the result set");
    my %has = map { $_->id => 1 } @objs;
    ok($has{$pid}, "parent is in the result set");
    ok($has{$cid}, "child is in the result set");

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;
    $test->db_is_valid;
}
cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{ # create parent and child and check functionality of 'apply_query_to_linked' arg
    my $parent = RT::Asset->new( RT->SystemUser );
    my ($pid) = $parent->Create( Name => 'parent', Catalog => 1 );
    ok( $pid, "created new asset" );
    $parent->SetStatus('stolen');

    my $child1 = RT::Asset->new( RT->SystemUser );
    my ($cid1) = $child1->Create( Name => 'child1', Catalog => 1, MemberOf => "asset:$pid" );
    ok( $cid1, "created new asset" );
    my $child2 = RT::Asset->new( RT->SystemUser );
    my ($cid2) = $child2->Create( Name => 'child2', Catalog => 1, MemberOf => "asset:$pid" );
    ok( $cid2, "created new asset" );
    $child2->SetStatus('stolen');

    my $plugin = RT::Shredder::Plugin::Assets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Assets');

    my ($status, $msg) = $plugin->TestArgs( query => 'Status = "stolen"', apply_query_to_linked => 1 );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    my @objs;
    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 2, "two objects in the result set");
    my %has = map { $_->id => 1 } @objs;
    ok($has{$pid}, "parent is in the result set");
    ok(!$has{$cid1}, "first child is in the result set");
    ok($has{$cid2}, "second child is in the result set");

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    my $asset = RT::Asset->new( RT->SystemUser );
    $asset->Load( $cid1 );
    is($asset->id, $cid1, 'loaded asset');

    $shredder->PutObjects( Objects => $asset );
    $shredder->WipeoutAll;
    $test->db_is_valid;
}
cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
