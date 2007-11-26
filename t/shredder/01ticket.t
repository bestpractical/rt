#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;

plan tests => 15;

BEGIN { require "t/shredder/utils.pl"; }
init_db();
create_savepoint('clean');

use RT::Model::Ticket;
use RT::Model::TicketCollection;

{
    my $ticket = RT::Model::Ticket->new( RT->system_user );
    my ($id) = $ticket->create( Subject => 'test', Queue => 1 );
    ok( $id, "Created new ticket" );
    $ticket->delete;
    is( $ticket->Status, 'deleted', "successfuly changed status" );

    my $tickets = RT::Model::TicketCollection->new( RT->system_user );
    $tickets->{'allow_deleted_search'} = 1;
    $tickets->LimitStatus( value => 'deleted' );
    is( $tickets->count, 1, "found one deleted ticket" );

    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => $tickets );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{
    my $parent = RT::Model::Ticket->new( RT->system_user );
    my ($pid) = $parent->create( Subject => 'test', Queue => 1 );
    ok( $pid, "Created new ticket" );
    create_savepoint('parent_ticket');

    my $child = RT::Model::Ticket->new( RT->system_user );
    my ($cid) = $child->create( Subject => 'test', Queue => 1 );
    ok( $cid, "Created new ticket" );

    my ($status, $msg) = $parent->AddLink( Type => 'MemberOf', Target => $cid );
    ok( $status, "Added link between tickets") or diag("error: $msg");
    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => $child );
    $shredder->WipeoutAll;
    cmp_deeply( dump_current_and_savepoint('parent_ticket'), "current DB equal to savepoint");

    $shredder->PutObjects( Objects => $parent );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{
    my $parent = RT::Model::Ticket->new( RT->system_user );
    my ($pid) = $parent->create( Subject => 'test', Queue => 1 );
    ok( $pid, "Created new ticket" );
    my ($status, $msg) = $parent->delete;
    ok( $status, 'deleted parent ticket');
    create_savepoint('parent_ticket');

    my $child = RT::Model::Ticket->new( RT->system_user );
    my ($cid) = $child->create( Subject => 'test', Queue => 1 );
    ok( $cid, "Created new ticket" );

    ($status, $msg) = $parent->AddLink( Type => 'DependsOn', Target => $cid );
    ok( $status, "Added link between tickets") or diag("error: $msg");
    my $shredder = shredder_new();
    $shredder->PutObjects( Objects => $child );
    $shredder->WipeoutAll;
    cmp_deeply( dump_current_and_savepoint('parent_ticket'), "current DB equal to savepoint");

    $shredder->PutObjects( Objects => $parent );
    $shredder->WipeoutAll;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

