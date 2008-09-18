#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use File::Spec;
use Test::Deep;
use RT::Test::Shredder;

RT::Test::Shredder::init_db();

plan tests => 3;

RT::Test::Shredder::create_savepoint();

use RT::Model::TicketCollection;
my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($id,undef,$cmsg) = $ticket->create( subject => 'test', queue => 1 );
ok( $id, "Created new ticket $cmsg " );

$ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($status, $msg) = $ticket->load( $id );
ok( $id, "load ticket" ) or diag( "error: $msg" );

my $shredder = RT::Test::Shredder::shredder_new();
$shredder->wipeout( object => $ticket );

cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint(), "current DB equal to savepoint");
