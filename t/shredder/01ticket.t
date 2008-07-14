#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test ();

plan tests => 15;

BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}

init_db();
create_savepoint('clean');

use RT::Model::Ticket;
use RT::Model::TicketCollection;

{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($id) = $ticket->create( subject => 'test', queue => 1 );
    ok( $id, "Created new ticket" );
    $ticket->set_status('deleted');
    is( $ticket->status, 'deleted', "successfuly changed status" );

    my $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user );
    $tickets->{'allow_deleted_search'} = 1;
    $tickets->limit_status( value => 'deleted' );
    is( $tickets->count, 1, "found one deleted ticket" );

    my $shredder = shredder_new();
    $shredder->put_objects( objects => $tickets );
    $shredder->wipeout_all;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{
    my $parent = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($pid) = $parent->create( subject => 'test', queue => 1 );
    ok( $pid, "Created new ticket" );
    create_savepoint('parent_ticket');

    my $child = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($cid) = $child->create( subject => 'test', queue => 1 );
    ok( $cid, "Created new ticket" );

    my ($status, $msg) = $parent->add_link( type => 'MemberOf', target => $cid );
    ok( $status, "Added link between tickets") or diag("error: $msg");
    my $shredder = shredder_new();
    $shredder->put_objects( objects => $child );
    $shredder->wipeout_all;
    cmp_deeply( dump_current_and_savepoint('parent_ticket'), "current DB equal to savepoint");

    $shredder->put_objects( objects => $parent );
    $shredder->wipeout_all;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

{
    my $parent = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($pid) = $parent->create( subject => 'test', queue => 1 );
    ok( $pid, "Created new ticket" );
    my ($status, $msg) = $parent->set_status('deleted');
    ok( $status, 'deleted parent ticket');
    create_savepoint('parent_ticket');

    my $child = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($cid) = $child->create( subject => 'test', queue => 1 );
    ok( $cid, "Created new ticket" );

    ($status, $msg) = $parent->add_link( type => 'DependsOn', target => $cid );
    ok( $status, "Added link between tickets") or diag("error: $msg");
    my $shredder = shredder_new();
    $shredder->put_objects( objects => $child );
    $shredder->wipeout_all;
    cmp_deeply( dump_current_and_savepoint('parent_ticket'), "current DB equal to savepoint");

    $shredder->put_objects( objects => $parent );
    $shredder->wipeout_all;
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
