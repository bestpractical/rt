#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 3;

create_savepoint();

use RT::Model::Tickets;
my $ticket = RT::Model::Ticket->new( $RT::SystemUser );
my ($id,undef,$cmsg) = $ticket->create( Subject => 'test', Queue => 1 );
ok( $id, "Created new ticket $cmsg " );

$ticket = RT::Model::Ticket->new( $RT::SystemUser );
my ($status, $msg) = $ticket->load( $id );
ok( $id, "load ticket" ) or diag( "error: $msg" );

my $shredder = shredder_new();
$shredder->Wipeout( Object => $ticket );

cmp_deeply( dump_current_and_savepoint(), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}
