
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 35;
my $test = "RT::Test::Shredder";

### nested membership check
{
        $test->create_savepoint('clean');
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

        $test->create_savepoint('bucreate'); # before user create
        my $user = RT::User->new( RT->SystemUser );
        my $uid;
        ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
        ok( $uid, "created new user" ) or diag "error: $msg";
        is( $user->id, $uid, "id is correct" );

        $test->create_savepoint('buadd'); # before group add
        ($status, $msg) = $cgroup->AddMember( $user->id );
        ok( $status, "added user to child group") or diag "error: $msg";

        my $members = RT::GroupMembers->new( RT->SystemUser );
        $members->Limit( FIELD => 'MemberId', VALUE => $uid );
        $members->Limit( FIELD => 'GroupId', VALUE => $cgid );
        is( $members->Count, 1, "find membership record" );

        my $transactions = RT::Transactions->new(RT->SystemUser);
        $transactions->_OpenParen('member');
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'Type', VALUE => 'AddMember');
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'Field', VALUE => $user->PrincipalObj->id, ENTRYAGGREGATOR => 'AND' );
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'ObjectId', VALUE => $cgroup->id, ENTRYAGGREGATOR => 'AND' );
        $transactions->_CloseParen('member');
        $transactions->_OpenParen('member');
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'Type', VALUE => 'AddMembership');
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'Field', VALUE => $cgroup->PrincipalObj->id, ENTRYAGGREGATOR => 'AND' );
        $transactions->Limit( SUBCLAUSE => 'member', FIELD => 'ObjectId', VALUE => $user->id, ENTRYAGGREGATOR => 'AND' );
        $transactions->_CloseParen('member');
        is( $transactions->Count, 2, "find membership transaction records" );

        my $shredder = $test->shredder_new();
        $shredder->PutObjects( Objects => [$members, $transactions] );
        $shredder->WipeoutAll();
        $test->db_is_valid;
        cmp_deeply( $test->dump_current_and_savepoint('buadd'), "current DB equal to savepoint");

        $shredder->PutObjects( Objects => $user );
        $shredder->WipeoutAll();
        $test->db_is_valid;
        cmp_deeply( $test->dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");

        $shredder->PutObjects( Objects => [$pgroup, $cgroup] );
        $shredder->WipeoutAll();
        $test->db_is_valid;
        cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

### deleting member of the ticket AdminCc role group
{
        $test->restore_savepoint('clean');

        my $user = RT::User->new( RT->SystemUser );
        my ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
        ok( $uid, "created new user" ) or diag "error: $msg";
        is( $user->id, $uid, "id is correct" );

        use RT::Queue;
        my $queue = RT::Queue->new( RT->SystemUser );
        $queue->Load('general');
        ok( $queue->id, "queue loaded succesfully" );

        use RT::Tickets;
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id) = $ticket->Create( Subject => 'test', Queue => $queue->id );
        ok( $id, "created new ticket" );
        $ticket = RT::Ticket->new( RT->SystemUser );
        my $status;
        ($status, $msg) = $ticket->Load( $id );
        ok( $id, "load ticket" ) or diag( "error: $msg" );

        ($status, $msg) = $ticket->AddWatcher( Type => "AdminCc", PrincipalId => $user->id );
        ok( $status, "AdminCC successfuly added") or diag( "error: $msg" );

        my $member = $ticket->AdminCc->MembersObj->First;
        my $shredder = $test->shredder_new();
        $shredder->PutObjects( Objects => $member );
        $shredder->WipeoutAll();
        $test->db_is_valid;

        $shredder->PutObjects( Objects => $user );
        $shredder->WipeoutAll();
        $test->db_is_valid;
}

### deleting member of the ticket Owner role group
{
        $test->restore_savepoint('clean');

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
        my $shredder = $test->shredder_new();
        $shredder->PutObjects( Objects => $member );
        $shredder->WipeoutAll();
        $test->db_is_valid;

        $ticket = RT::Ticket->new( RT->SystemUser );
        ($status, $msg) = $ticket->Load( $id );
        ok( $id, "load ticket" ) or diag( "error: $msg" );
        is( $ticket->Owner, RT->Nobody->id, "owner switched back to nobody" );
        is( $ticket->OwnerGroup->MembersObj->First->MemberId, RT->Nobody->id, "and owner role group member is nobody");
}
