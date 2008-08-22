#!/usr/bin/perl -w
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
#                                          <jesse.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}

use Test::More tests => 28;
use RT::Test;

use strict;
use warnings;
no warnings 'once';

use RT::Model::Queue;
use RT::Model::User;
use RT::Group;
use RT::Model::Ticket;
use RT::CurrentUser;


# clear all global right
my $acl = RT::ACL->new($RT::SystemUser);
$acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );
$acl->LimitToObject( $RT::System );
while( my $ace = $acl->next ) {
	$ace->Delete;
}

# create new queue to be sure we do not mess with rights
my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'watcher tests '.$$);
ok( $queue_id, 'queue created for watcher tests' );

# new privileged user to check rights
my $user = RT::Model::User->new(current_user => RT->system_user );
my ($user_id) = $user->create( name =>  'watcher'.$$,
			   email => "watcher$$".'@localhost',
			   privileged => 1,
			   Password => 'qwe123',
			 );
my $cu= RT::CurrentUser->new($user);

# make sure user can see tickets in the queue
my $principal = $user->principal_object;
ok( $principal, "principal loaded" );
$principal->grant_right( Right => 'ShowTicket', Object => $queue );
$principal->grant_right( Right => 'SeeQueue'  , Object => $queue );

ok(  $user->HasRight( Right => 'SeeQueue',     Object => $queue ), "user can see queue" );
ok(  $user->HasRight( Right => 'ShowTicket',   Object => $queue ), "user can show queue tickets" );
ok( !$user->HasRight( Right => 'ModifyTicket', Object => $queue ), "user can't modify queue tickets" );
ok( !$user->HasRight( Right => 'Watch',        Object => $queue ), "user can't watch queue tickets" );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( Subject => 'watcher tests', Queue => $queue->Name );
ok( $ticket->id, "ticket created" );

my $ticket2 = RT::Model::Ticket->new(current_user => $cu );
$ticket2->Load( $ticket->id );
ok( $ticket2->Subject, "ticket load by user" );

# user can add self to ticket only after getting Watch right
($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', principal_id => $user->principal_id );
ok( !$rv, "user can't add self as Cc" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', principal_id => $user->principal_id );
ok( !$rv, "user can't add self as Requestor" );
$principal->grant_right( Right => 'Watch'  , Object => $queue );
ok(  $user->HasRight( Right => 'Watch',        Object => $queue ), "user can watch queue tickets" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', principal_id => $user->principal_id );
ok(  $rv, "user can add self as Cc by principal_id" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', principal_id => $user->principal_id );
ok(  $rv, "user can add self as Requestor by principal_id" );

# remove user and try adding with Email address
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Cc',        principal_id => $user->principal_id );
ok( $rv, "watcher removed by principal_id" );
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Requestor', Email => $user->email );
ok( $rv, "watcher removed by Email" );

($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', Email => $user->email );
ok(  $rv, "user can add self as Cc by Email" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', Email => $user->email );
ok(  $rv, "user can add self as Requestor by Email" );

# Queue watcher tests
$principal->revoke_right( Right => 'Watch'  , Object => $queue );
ok( !$user->HasRight( Right => 'Watch',        Object => $queue ), "user queue watch right revoked" );

my $queue2 = RT::Model::Queue->new( $cu );
($rv, $msg) = $queue2->Load( $queue->id );
ok( $rv, "user loaded queue" );

# user can add self to queue only after getting Watch right
($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', principal_id => $user->principal_id );
ok( !$rv, "user can't add self as Cc" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', principal_id => $user->principal_id );
ok( !$rv, "user can't add self as Requestor" );
$principal->grant_right( Right => 'Watch'  , Object => $queue );
ok(  $user->HasRight( Right => 'Watch',        Object => $queue ), "user can watch queue queues" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', principal_id => $user->principal_id );
ok(  $rv, "user can add self as Cc by principal_id" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', principal_id => $user->principal_id );
ok(  $rv, "user can add self as Requestor by principal_id" );

# remove user and try adding with Email address
($rv, $msg) = $queue->DeleteWatcher( Type => 'Cc',        principal_id => $user->principal_id );
ok( $rv, "watcher removed by principal_id" );
($rv, $msg) = $queue->DeleteWatcher( Type => 'Requestor', Email => $user->email );
ok( $rv, "watcher removed by Email" );

($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', Email => $user->email );
ok(  $rv, "user can add self as Cc by Email" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', Email => $user->email );
ok(  $rv, "user can add self as Requestor by Email" );


