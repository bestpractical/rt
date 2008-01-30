#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 22;

### nested membership check
{
	create_savepoint('clean');
	my $pgroup = RT::Model::Group->new(current_user => RT->system_user );
	my ($pgid) = $pgroup->create_user_defined_group( name => 'Parent group' );
	ok( $pgid, "Created parent group" );
	is( $pgroup->id, $pgid, "id is correct" );
	
	my $cgroup = RT::Model::Group->new(current_user => RT->system_user );
	my ($cgid) = $cgroup->create_user_defined_group( name => 'Child group' );
	ok( $cgid, "Created child group" );
	is( $cgroup->id, $cgid, "id is correct" );
	
	my ($status, $msg) = $pgroup->add_member( $cgroup->id );
	ok( $status, "added child group to parent") or diag "error: $msg";
	
	create_savepoint('bucreate'); # before user create
	my $user = RT::Model::User->new(current_user => RT->system_user );
	my $uid;
	($uid, $msg) = $user->create( name => 'new user', privileged => 1, disabled => 0 );
	ok( $uid, "Created new user $msg " ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );
	
	create_savepoint('buadd'); # before group add
	($status, $msg) = $cgroup->add_member( $user->id );
	ok( $status, "added user to child group") or diag "error: $msg";
	
	my $members = RT::Model::GroupMemberCollection->new( current_user => RT->system_user );
	$members->limit( column => 'MemberId', value => $uid );
	$members->limit( column => 'GroupId', value => $cgid );
	is( $members->count, 1, "find membership record" );
	
	my $shredder = shredder_new();
	$shredder->put_objects( objects => $members );
	$shredder->wipeout_all();
	cmp_deeply( dump_current_and_savepoint('buadd'), "current DB equal to savepoint");
	
	$shredder->put_objects( objects => $user );
	$shredder->wipeout_all();
	cmp_deeply( dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");
	
	$shredder->put_objects( objects => [$pgroup, $cgroup] );
	$shredder->wipeout_all();
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

### deleting member of the ticket Owner role group
{
	restore_savepoint('clean');

	my $user = RT::Model::User->new(current_user => RT->system_user );
	my ($uid, $msg) = $user->create( name => 'new user', privileged => 1, disabled => 0 );
	ok( $uid, "Created new user" ) or diag "error: $msg";
	is( $user->id, $uid, "id is correct" );

	use RT::Model::Queue;
	my $queue = RT::Model::Queue->new( current_user => RT->system_user );
	$queue->load('General');
	ok( $queue->id, "queue loaded succesfully" );

	$user->principal_object->grant_right( Right => 'OwnTicket', object => $queue );

	use RT::Model::TicketCollection;
	my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
	my ($id) = $ticket->create( subject => 'test', Queue => $queue->id );
	ok( $id, "Created new ticket" );
	$ticket = RT::Model::Ticket->new(current_user => RT->system_user );
	my $status;
	($status, $msg) = $ticket->load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );
	($status, $msg) = $ticket->set_owner( $user->id );
	ok( $status, "owner successfuly set") or diag( "error: $msg" );
	is( $ticket->owner, $user->id, "owner successfuly set") or diag( "error: $msg" );

	my $member = $ticket->owner_group->members_obj->first;
	my $shredder = shredder_new();
	$shredder->put_objects( objects => $member );
	$shredder->wipeout_all();

	$ticket = RT::Model::Ticket->new(current_user => RT->system_user );
	($status, $msg) = $ticket->load( $id );
	ok( $id, "load ticket" ) or diag( "error: $msg" );
	is( $ticket->owner, RT->nobody->id, "owner switched back to nobody" );
	is( $ticket->owner_group->members_obj->first->member_id, RT->nobody->id, "and owner role group member is nobody");
}


if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}
