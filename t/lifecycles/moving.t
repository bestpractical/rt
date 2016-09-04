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

diag "check moving without a map";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue => $general->id,
        Subject => 'test',
        Status => 'new',
    );
    ok $id, 'created a ticket';
    (my $status, $msg) = $ticket->SetQueue( $delivery->id );
    ok !$status, "couldn't change queue when there is no maps between schemas";
    is $ticket->Queue, $general->id, 'queue is steal the same';
    is $ticket->Status, 'new', 'status is steal the same';
}

diag "add partial map";
{
    my $schemas = RT->Config->Get('Lifecycles');
    $schemas->{'__maps__'} = {
        'default -> delivery' => {
            new => 'ordered',
        },
    };
    RT::Lifecycle->FillCache;
}

diag "check moving with a partial map";
{
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';
        (my $status, $msg) = $ticket->SetQueue( $delivery->id );
        ok $status, "moved ticket between queues with different schemas";
        is $ticket->Queue, $delivery->id, 'queue has been changed'
            or diag "error: $msg";
        is $ticket->Status, 'ordered', 'status has been changed';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'open',
        );
        ok $id, 'created a ticket';
        (my $status, $msg) = $ticket->SetQueue( $delivery->id );
        ok !$status, "couldn't change queue when map is not complete";
        is $ticket->Queue, $general->id, 'queue is steal the same';
        is $ticket->Status, 'open', 'status is steal the same';
    }
}

diag "one way map doesn't work backwards";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue => $delivery->id,
        Subject => 'test',
        Status => 'ordered',
    );
    ok $id, 'created a ticket';
    (my $status, $msg) = $ticket->SetQueue( $general->id );
    ok !$status, "couldn't change queue when there is no maps between schemas";
    is $ticket->Queue, $delivery->id, 'queue is steal the same';
    is $ticket->Status, 'ordered', 'status is steal the same';
}

done_testing;
