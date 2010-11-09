#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 8;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}
init_db();


create_savepoint('clean');

my $queue = RT::Queue->new( RT->SystemUser );
my ($qid) = $queue->Load( 'General' );
ok( $qid, "loaded queue" );

my $ticket = RT::Ticket->new( RT->SystemUser );
my ($tid) = $ticket->Create( Queue => $qid, Subject => 'test' );
ok( $tid, "ticket created" );

create_savepoint('bucreate'); # berfore user create
my $user = RT::User->new( RT->SystemUser );
my ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
ok( $uid, "created new user" ) or diag "error: $msg";
is( $user->id, $uid, "id is correct" );
# HACK: set ticket props to enable VARIABLE dependencies
$ticket->__Set( Field => 'LastUpdatedBy', Value => $uid );
create_savepoint('aucreate'); # after user create

{
    my $resolver = sub {
        my %args = (@_);
        my $t =	$args{'TargetObject'};
        my $resolver_uid = RT->SystemUser->id;
        foreach my $method ( qw(Creator LastUpdatedBy) ) {
            next unless $t->_Accessible( $method => 'read' );
            $t->__Set( Field => $method, Value => $resolver_uid );
        }
    };
    my $shredder = shredder_new();
    $shredder->PutResolver( BaseClass => 'RT::User', Code => $resolver );
    $shredder->Wipeout( Object => $user );
    cmp_deeply( dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");
}

{
    restore_savepoint('aucreate');
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($uid);
    ok($user->id, "loaded user after restore");
    my $shredder = shredder_new();
    eval { $shredder->Wipeout( Object => $user ) };
    ok($@, "wipeout throw exception if no resolvers");
    cmp_deeply( dump_current_and_savepoint('aucreate'), "current DB equal to savepoint");
}
