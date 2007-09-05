#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 22;

### nested membership check
{
	create_savepoint('clean');
	my $pgroup = RT::Model::Group->new( $RT::SystemUser );
	my ($pgid) = $pgroup->create_userDefinedGroup( Name => 'Parent group' );
	ok( $pgid, "Created parent group" );
	is( $pgroup->id, $pgid, "id is correct" );
	
	my $cgroup = RT::Model::Group->new( $RT::SystemUser );
	my ($cgid) = $cgroup->create_userDefinedGroup( Name => 'Child group' );
	ok( $cgid, "Created child group" );
	is( $cgroup->id, $cgid, "id is correct" );
	
	my ($status, $msg) = $pgroup->AddMember( $cgroup->id );
	ok( $status, "added child group to parent") or diag "error: $msg";
	
	create_savepoint('bucreate'); # before user create
	my $user = RT::Model::User->new( $RT::SystemUser );
	my $uid;
	($uid, $msg) = $user->create( Name => 'new user', Privileged => 1, Disabled => 0 );
	ok( $uid, "Created new user" ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );
	
	create_savepoint('buadd'); # before group add
	($status, $msg) = $cgroup->AddMember( $user->id );
	ok( $status, "added user to child group") or diag "error: $msg";
	
	my $members = RT::Model::GroupMembers->new( $RT::SystemUser );
	$members->limit( column => 'MemberId', value => $uid );
	$members->limit( column => 'GroupId', value => $cgid );
	is( $members->count, 1, "find membership record" );
	
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

	my $user = RT::Model::User->new( $RT::SystemUser );
	my ($uid, $msg) = $user->create( Name => 'new user', Privileged => 1, Disabled => 0 );
	ok( $uid, "Created new user" ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );

	use RT::Model::Queue;
	my $queue = new RT::Model::Queue( $RT::SystemUser );
	$queue->load('General');
	ok( $queue->id, "queue loaded succesfully" );

	$user->PrincipalObj->GrantRight( Right => 'OwnTicket', Object => $queue );

	use RT::Model::Tickets;
	my $ticket = RT::Model::Ticket->new( $RT::SystemUser );
	my ($id) = $ticket->create( Subject => 'test', Queue => $queue->id );
	ok( $id, "Created new ticket" );
	$ticket = RT::Model::Ticket->new( $RT::SystemUser );
	my $status;
	($status, $msg) = $ticket->load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );
	($status, $msg) = $ticket->set_Owner( $user->id );
	ok( $status, "owner successfuly set") or diag( "error: $msg" );
	is( $ticket->Owner, $user->id, "owner successfuly set") or diag( "error: $msg" );

	my $member = $ticket->OwnerGroup->MembersObj->first;
	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $member );
	$shredder->WipeoutAll();

	$ticket = RT::Model::Ticket->new( $RT::SystemUser );
	($status, $msg) = $ticket->load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );
	is( $ticket->Owner, $RT::Nobody->id, "owner switched back to nobody" );
	is( $ticket->OwnerGroup->MembersObj->first->MemberId, $RT::Nobody->id, "and owner role group member is nobody");
}


if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}
