#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 44;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}


use_ok('RT::Shredder::Plugin::Tickets');
{
    my $plugin = RT::Shredder::Plugin::Tickets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Tickets');

    is(lc $plugin->Type, 'search', 'correct type');
}

init_db();
create_savepoint('clean');
use_ok('RT::Ticket');
use_ok('RT::Tickets');

{ # create parent and child and check functionality of 'with_linked' arg
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($pid) = $parent->Create( Subject => 'parent', Queue => 1 );
    ok( $pid, "created new ticket" );
    my $child = RT::Ticket->new( RT->SystemUser );
    my ($cid) = $child->Create( Subject => 'child', Queue => 1, MemberOf => $pid );
    ok( $cid, "created new ticket" );

    my $plugin = RT::Shredder::Plugin::Tickets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Tickets');

    my ($status, $msg, @objs);
    ($status, $msg) = $plugin->TestArgs( query => 'Subject = "parent"' );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 1, "only one object in result set");
    is($objs[0]->id, $pid, "parent is in result set");

    ($status, $msg) = $plugin->TestArgs( query => 'Subject = "parent"', with_linked => 1 );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    my %has = map { $_->id => 1 } @objs;
    is(scalar @objs, 2, "two objects in the result set");
    ok($has{$pid}, "parent is in the result set");
    ok($has{$cid}, "child is in the result set");

    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{ # create parent and child and link them reqursively to check that we don't hang
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($pid) = $parent->Create( Subject => 'parent', Queue => 1 );
    ok( $pid, "created new ticket" );

    my $child = RT::Ticket->new( RT->SystemUser );
    my ($cid) = $child->Create( Subject => 'child', Queue => 1, MemberOf => $pid );
    ok( $cid, "created new ticket" );

    my ($status, $msg) = $child->AddLink( Target => $pid, Type => 'DependsOn' );
    ok($status, "added reqursive link") or diag "error: $msg";

    my $plugin = RT::Shredder::Plugin::Tickets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Tickets');

    my (@objs);
    ($status, $msg) = $plugin->TestArgs( query => 'Subject = "parent"' );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 1, "only one object in result set");
    is($objs[0]->id, $pid, "parent is in result set");

    ($status, $msg) = $plugin->TestArgs( query => 'Subject = "parent"', with_linked => 1 );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 2, "two objects in the result set");
    my %has = map { $_->id => 1 } @objs;
    ok($has{$pid}, "parent is in the result set");
    ok($has{$cid}, "child is in the result set");

    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{ # create parent and child and check functionality of 'apply_query_to_linked' arg
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($pid) = $parent->Create( Subject => 'parent', Queue => 1 );
    ok( $pid, "created new ticket" );
    $parent->SetStatus('resolved');

    my $child1 = RT::Ticket->new( RT->SystemUser );
    my ($cid1) = $child1->Create( Subject => 'child', Queue => 1, MemberOf => $pid );
    ok( $cid1, "created new ticket" );
    my $child2 = RT::Ticket->new( RT->SystemUser );
    my ($cid2) = $child2->Create( Subject => 'child', Queue => 1, MemberOf => $pid);
    ok( $cid2, "created new ticket" );
    $child2->SetStatus('resolved');

    my $plugin = RT::Shredder::Plugin::Tickets->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Tickets');

    my ($status, $msg) = $plugin->TestArgs( query => 'Status = "resolved"', apply_query_to_linked => 1 );
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

    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $cid1 );
    is($ticket->id, $cid1, 'loaded ticket');

    $shredder->PutObjects( Objects => $ticket );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
