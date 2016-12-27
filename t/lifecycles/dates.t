use strict;
use warnings;

BEGIN {require './t/lifecycles/utils.pl'};

my $general = RT::Test->load_or_create_queue(
    Name => 'General',
);
ok $general && $general->id, 'loaded or created a queue';

my $delivery = RT::Test->load_or_create_queue(
    Name => 'delivery',
    Lifecycle => 'delivery',
);
ok $delivery && $delivery->id, 'loaded or created a queue';

my $tstatus = sub {
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $_[0] );
    return $ticket->Status;
};

diag "check basic API";
{
    my $schema = $general->LifecycleObj;
    isa_ok($schema, 'RT::Lifecycle');
    is $schema->Name, 'default', "it's a default schema";

    $schema = $delivery->LifecycleObj;
    isa_ok($schema, 'RT::Lifecycle');
    is $schema->Name, 'delivery', "it's a delivery schema";
}

diag "dates on create for default schema";
{
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';
        ok !$ticket->StartedObj->IsSet, 'started is not set';
        ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'open',
        );
        ok $id, 'created a ticket';
        ok $ticket->StartedObj->IsSet, 'started is set';
        ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'resolved',
        );
        ok $id, 'created a ticket';
        ok $ticket->StartedObj->IsSet, 'started is set';
        ok $ticket->ResolvedObj->IsSet, 'resolved is set';
    }

    my $test_date = '2008-11-28 12:00:00';
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'open',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'resolved',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
    }
}

diag "dates on create for delivery schema";
{
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
            Status => 'ordered',
        );
        ok $id, 'created a ticket';
        is $ticket->StartedObj->Unix , 0, 'started is not set';
        is $ticket->ResolvedObj->Unix, 0, 'resolved is not set';

    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $txn, $msg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
        );
        ok $id, 'created a ticket';
        diag($msg);
        is $ticket->Status, 'ordered', "Status is ordered";
        my ($statusval,$statusmsg) = $ticket->SetStatus('on way');
        ok($statusval,$statusmsg);
        ok $ticket->StartedObj->IsSet, 'started is set to ' .$ticket->StartedObj->AsString ;
        is $ticket->ResolvedObj->Unix, 0, 'resolved is not set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
        );
        ok $id, 'created a ticket';

        my ($statusval,$statusmsg) = $ticket->SetStatus('on way');
        ok($statusval,$statusmsg);

        ($statusval,$statusmsg) = $ticket->SetStatus('delivered');
        ok($statusval,$statusmsg);

        ok $ticket->StartedObj->IsSet, 'started is set';
        ok $ticket->ResolvedObj->IsSet, 'resolved is set';
    }

    my $test_date = '2008-11-28 12:00:00';
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $statusmsg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
            Status => 'ordered',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
            Status => 'ordered',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        my ($statusval,$statusmsg) = $ticket->SetStatus('on way');
        ok($statusval,$statusmsg);
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $delivery->id,
            Subject => 'test',
            Started => $test_date,
            Resolved => $test_date,
        );
        ok $id, 'created a ticket';
        my ($statusval,$statusmsg) = $ticket->SetStatus('on way');
        ok($statusval,$statusmsg);
        ($statusval,$statusmsg) = $ticket->SetStatus('delivered');
        ok($statusval,$statusmsg);
        is $ticket->StartedObj->ISO, $test_date, 'started is set';
        TODO: {
            local $TODO = "we should decide if we set resolved repeatedly";
            is $ticket->ResolvedObj->ISO, $test_date, 'resolved is set';
        };
    }
}

diag "dates on status change for default schema";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue => $general->id,
        Subject => 'test',
        Status => 'new',
    );
    ok $id, 'created a ticket';
    ok !$ticket->StartedObj->IsSet, 'started is not set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    (my $status, $msg) = $ticket->SetStatus('open');
    ok $status, 'changed status' or diag "error: $msg";
    ok $ticket->StartedObj->IsSet, 'started is set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    my $started = $ticket->StartedObj->Unix;

    ($status, $msg) = $ticket->SetStatus('stalled');
    ok $status, 'changed status' or diag "error: $msg";
    is $ticket->StartedObj->Unix, $started, 'started is set and the same';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    ($status, $msg) = $ticket->SetStatus('open');
    ok $status, 'changed status' or diag "error: $msg";
    is $ticket->StartedObj->Unix, $started, 'started is set and the same';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    ($status, $msg) = $ticket->SetStatus('resolved');
    ok $status, 'changed status' or diag "error: $msg";
    is $ticket->StartedObj->Unix, $started, 'started is set and the same';
    ok $ticket->ResolvedObj->IsSet, 'resolved is set';
}

diag "dates on status change for delivery schema";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue => $delivery->id,
        Subject => 'test',
        Status => 'ordered',
    );
    ok $id, 'created a ticket';
    ok !$ticket->StartedObj->IsSet, 'started is not set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    (my $status, $msg) = $ticket->SetStatus('delayed');
    ok $status, 'changed status' or diag "error: $msg";
    ok $ticket->StartedObj->IsSet, 'started is set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    my $started = $ticket->StartedObj->Unix;

    ($status, $msg) = $ticket->SetStatus('on way');
    ok $status, 'changed status' or diag "error: $msg";
    is $ticket->StartedObj->Unix, $started, 'started is set and the same';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    ($status, $msg) = $ticket->SetStatus('delivered');
    ok $status, 'changed status' or diag "error: $msg";
    is $ticket->StartedObj->Unix, $started, 'started is set and the same';
    ok $ticket->ResolvedObj->IsSet, 'resolved is set';
}

diag "add partial map between general->delivery";
{
    my $schemas = RT->Config->Get('Lifecycles');
    $schemas->{'__maps__'} = {
        'default -> delivery' => {
            new => 'on way',
        },
        'delivery -> default' => {
            'on way' => 'resolved',
        },
    };
    RT::Lifecycle->FillCache;
}

diag "check date changes on moving a ticket";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue => $general->id,
        Subject => 'test',
        Status => 'new',
    );
    ok $id, 'created a ticket';
    ok !$ticket->StartedObj->IsSet, 'started is not set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    (my $status, $msg) = $ticket->SetQueue( $delivery->id );
    ok $status, "moved ticket between queues with different schemas";
    is $ticket->Status, 'on way', 'status has been changed';
    ok $ticket->StartedObj->IsSet, 'started is set';
    ok !$ticket->ResolvedObj->IsSet, 'resolved is not set';

    ($status, $msg) = $ticket->SetQueue( $general->id );
    ok $status, "moved ticket between queues with different schemas";
    is $ticket->Status, 'resolved', 'status has been changed';
    ok $ticket->StartedObj->IsSet, 'started is set';
    ok $ticket->ResolvedObj->IsSet, 'resolved is set';
}

done_testing;
