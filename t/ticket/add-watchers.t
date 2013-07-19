use RT::Test nodata => 1, tests => 34;

use strict;
use warnings;

use RT::Queue;
use RT::User;
use RT::Group;
use RT::Ticket;
use RT::CurrentUser;


# clear all global right
my $acl = RT::ACL->new(RT->SystemUser);
$acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );
$acl->LimitToObject( RT->System );
while( my $ace = $acl->Next ) {
    $ace->Delete;
}

# create new queue to be sure we do not mess with rights
my $queue = RT::Queue->new(RT->SystemUser);
my ($queue_id) = $queue->Create( Name => 'watcher tests '.$$);
ok( $queue_id, 'queue created for watcher tests' );

# new privileged user to check rights
my $user = RT::User->new( RT->SystemUser );
my ($user_id) = $user->Create(
    Name => 'watcher'.$$,
    EmailAddress => "watcher$$".'@localhost',
    Privileged => 1,
    Password => 'qwe123',
);
my $cu= RT::CurrentUser->new($user);

# make sure user can see tickets in the queue
my $principal = $user->PrincipalObj;
ok( $principal, "principal loaded" );
$principal->GrantRight( Right => 'ShowTicket', Object => $queue );
$principal->GrantRight( Right => 'SeeQueue'  , Object => $queue );

ok(  $user->HasRight( Right => 'SeeQueue',     Object => $queue ), "user can see queue" );
ok(  $user->HasRight( Right => 'ShowTicket',   Object => $queue ), "user can show queue tickets" );
ok( !$user->HasRight( Right => 'ModifyTicket', Object => $queue ), "user can't modify queue tickets" );
ok( !$user->HasRight( Right => 'Watch',        Object => $queue ), "user can't watch queue tickets" );

my $ticket = RT::Ticket->new( RT->SystemUser );
my ($rv, $msg) = $ticket->Create( Subject => 'watcher tests', Queue => $queue->Name );
ok( $ticket->id, "ticket created" );

my $ticket2 = RT::Ticket->new( $cu );
$ticket2->Load( $ticket->id );
ok( $ticket2->Subject, "ticket load by user" );

# user can add self to ticket only after getting Watch right
($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', PrincipalId => $user->PrincipalId );
ok( !$rv, "user can't add self as Cc" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', PrincipalId => $user->PrincipalId );
ok( !$rv, "user can't add self as Requestor" );
$principal->GrantRight( Right => 'Watch'  , Object => $queue );
ok(  $user->HasRight( Right => 'Watch',        Object => $queue ), "user can watch queue tickets" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', PrincipalId => $user->PrincipalId );
ok(  $rv, "user can add self as Cc by PrincipalId" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', PrincipalId => $user->PrincipalId );
ok(  $rv, "user can add self as Requestor by PrincipalId" );

# remove user and try adding with Email address
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Cc',        PrincipalId => $user->PrincipalId );
ok( $rv, "watcher removed by PrincipalId" );
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Requestor', Email => $user->EmailAddress );
ok( $rv, "watcher removed by Email" );

($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', Email => $user->EmailAddress );
ok(  $rv, "user can add self as Cc by Email" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', Email => $user->EmailAddress );
ok(  $rv, "user can add self as Requestor by Email" );

# remove user and try adding by username
# This worked in 3.6 and is a regression in 3.8
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Cc', Email => $user->EmailAddress );
ok( $rv, "watcher removed by Email" );
($rv, $msg) = $ticket->DeleteWatcher( Type => 'Requestor', Email => $user->EmailAddress );
ok( $rv, "watcher removed by Email" );

($rv, $msg) = $ticket2->AddWatcher( Type => 'Cc', Email => $user->Name );
ok(  $rv, "user can add self as Cc by username" );
($rv, $msg) = $ticket2->AddWatcher( Type => 'Requestor', Email => $user->Name );
ok(  $rv, "user can add self as Requestor by username" );

# Add an email address with a phrase
($rv, $msg) = $ticket->AddWatcher( Type => 'Cc', Email => q["Foo Bar" <foo@example.com>] );
ok $rv, "Added email address with phrase" or diag $msg;

my $foo = RT::Test->load_or_create_user( EmailAddress => 'foo@example.com' );
is $foo->RealName, "Foo Bar", "RealName matches";

# Queue watcher tests
$principal->RevokeRight( Right => 'Watch'  , Object => $queue );
ok( !$user->HasRight( Right => 'Watch',        Object => $queue ), "user queue watch right revoked" );

my $queue2 = RT::Queue->new( $cu );
($rv, $msg) = $queue2->Load( $queue->id );
ok( $rv, "user loaded queue" );

# user can add self to queue only after getting Watch right
($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', PrincipalId => $user->PrincipalId );
ok( !$rv, "user can't add self as Cc" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', PrincipalId => $user->PrincipalId );
ok( !$rv, "user can't add self as Requestor" );
$principal->GrantRight( Right => 'Watch'  , Object => $queue );
ok(  $user->HasRight( Right => 'Watch',        Object => $queue ), "user can watch queue queues" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', PrincipalId => $user->PrincipalId );
ok(  $rv, "user can add self as Cc by PrincipalId" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', PrincipalId => $user->PrincipalId );
ok(  $rv, "user can add self as Requestor by PrincipalId" );

# remove user and try adding with Email address
($rv, $msg) = $queue->DeleteWatcher( Type => 'Cc',        PrincipalId => $user->PrincipalId );
ok( $rv, "watcher removed by PrincipalId" );
($rv, $msg) = $queue->DeleteWatcher( Type => 'Requestor', Email => $user->EmailAddress );
ok( $rv, "watcher removed by Email" );

($rv, $msg) = $queue2->AddWatcher( Type => 'Cc', Email => $user->EmailAddress );
ok(  $rv, "user can add self as Cc by Email" );
($rv, $msg) = $queue2->AddWatcher( Type => 'Requestor', Email => $user->EmailAddress );
ok(  $rv, "user can add self as Requestor by Email" );

