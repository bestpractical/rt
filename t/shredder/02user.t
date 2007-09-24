#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 8;

create_savepoint('clean');

my $queue = RT::Model::Queue->new( RT->SystemUser );
my ($qid) = $queue->load( 'General' );
ok( $qid, "loaded queue" );

my $ticket = RT::Model::Ticket->new( RT->SystemUser );
my ($tid) = $ticket->create( Queue => $qid, Subject => 'test' );
ok( $tid, "ticket Created" );

create_savepoint('bucreate'); # berfore user create
my $user = RT::Model::User->new( RT->SystemUser );
my ($uid, $msg) = $user->create( Name => 'new user', Privileged => 1, Disabled => 0 );
ok( $uid, "Created new user" ) or diag "error: $msg";
is( $user->id, $uid, "id is correct" );
# HACK: set ticket props to enable VARIABLE dependencies
$ticket->__set( column => 'LastUpdatedBy', value => $uid );
create_savepoint('aucreate'); # after user create

{
    my $resolver = sub {
        my %args = (@_);
        my $t =	$args{'TargetObject'};
        my $resolver_uid = RT->SystemUser->id;
        foreach my $method ( qw(Creator LastUpdatedBy) ) {
            next unless $t->can($method);
            $t->__set( column => $method, value => $resolver_uid );
        }
    };
    my $shredder = shredder_new();
    $shredder->PutResolver( BaseClass => 'RT::Model::User', Code => $resolver );
    $shredder->Wipeout( Object => $user );
    cmp_deeply( dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");
}

{
    restore_savepoint('aucreate');
    my $user = RT::Model::User->new( RT->SystemUser );
    $user->load($uid);
    ok($user->id, "loaded user after restore");
    my $shredder = shredder_new();
    eval { $shredder->Wipeout( Object => $user ) };
    ok($@, "wipeout throw exception if no resolvers");
    cmp_deeply( dump_current_and_savepoint('aucreate'), "current DB equal to savepoint");
}

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

