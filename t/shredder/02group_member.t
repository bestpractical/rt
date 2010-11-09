#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 22;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}
init_db();


### nested membership check
{
	create_savepoint('clean');
	my $pgroup = RT::Group->new( RT->SystemUser );
	my ($pgid) = $pgroup->CreateUserDefinedGroup( Name => 'Parent group' );
	ok( $pgid, "created parent group" );
	is( $pgroup->id, $pgid, "id is correct" );
	
	my $cgroup = RT::Group->new( RT->SystemUser );
	my ($cgid) = $cgroup->CreateUserDefinedGroup( Name => 'Child group' );
	ok( $cgid, "created child group" );
	is( $cgroup->id, $cgid, "id is correct" );
	
	my ($status, $msg) = $pgroup->AddMember( $cgroup->id );
	ok( $status, "added child group to parent") or diag "error: $msg";
	
	create_savepoint('bucreate'); # before user create
	my $user = RT::User->new( RT->SystemUser );
	my $uid;
	($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
	ok( $uid, "created new user" ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );
	
	create_savepoint('buadd'); # before group add
	($status, $msg) = $cgroup->AddMember( $user->id );
	ok( $status, "added user to child group") or diag "error: $msg";
	
	my $members = RT::GroupMembers->new( RT->SystemUser );
	$members->Limit( FIELD => 'MemberId', VALUE => $uid );
	$members->Limit( FIELD => 'GroupId', VALUE => $cgid );
	is( $members->Count, 1, "find membership record" );
	
	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $members );
	$shredder->WipeoutAll();
	cmp_deeply( dump_current_and_savepoint('buadd'), "current DB equal to savepoint");
	
	$shredder->PutObjects( Objects => $user );
	$shredder->WipeoutAll();
	cmp_deeply( dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");
	
	$shredder->PutObjects( Objects => [$pgroup, $cgroup] );
	$shredder->WipeoutAll();
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

### deleting member of the ticket Owner role group
{
	restore_savepoint('clean');

	my $user = RT::User->new( RT->SystemUser );
	my ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
	ok( $uid, "created new user" ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );

	use RT::Queue;
	my $queue = RT::Queue->new( RT->SystemUser );
	$queue->Load('general');
	ok( $queue->id, "queue loaded succesfully" );

	$user->PrincipalObj->GrantRight( Right => 'OwnTicket', Object => $queue );

	use RT::Tickets;
	my $ticket = RT::Ticket->new( RT->SystemUser );
	my ($id) = $ticket->Create( Subject => 'test', Queue => $queue->id );
	ok( $id, "created new ticket" );
	$ticket = RT::Ticket->new( RT->SystemUser );
	my $status;
	($status, $msg) = $ticket->Load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );

	($status, $msg) = $ticket->SetOwner( $user->id );
	ok( $status, "owner successfuly set") or diag( "error: $msg" );
	is( $ticket->Owner, $user->id, "owner successfuly set") or diag( "error: $msg" );

	my $member = $ticket->OwnerGroup->MembersObj->First;
	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $member );
	$shredder->WipeoutAll();

	$ticket = RT::Ticket->new( RT->SystemUser );
	($status, $msg) = $ticket->Load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );
	is( $ticket->Owner, RT->Nobody->id, "owner switched back to nobody" );
	is( $ticket->OwnerGroup->MembersObj->First->MemberId, RT->Nobody->id, "and owner role group member is nobody");
}
