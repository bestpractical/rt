use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->load_or_create_queue( Name => 'General', SLADisabled => 0 );

diag 'check that reply to requestors dont unset due date with KeepInLoop' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(ServiceAgreements => (
        Default => '2',
        Levels => {
            '2' => {
                KeepInLoop => { RealMinutes => 60*4, IgnoreOnStatuses => ['stalled'] },
            },
        },
    ));

    my $root = RT::User->new( $RT::SystemUser );
    $root->LoadByEmail('root@localhost');
    ok $root->id, 'loaded root user';

    # requestor creates
    my $id;
    my $due;
    {
        my $ticket = RT::Ticket->new( $root );
        ($id) = $ticket->Create(
            Queue => 'General',
            Subject => 'xxx',
            Requestor => $root->id,
        );
        ok $id, "created ticket #$id";
        is $ticket->SLA, '2', 'default sla';
        ok !$ticket->DueObj->Unix, 'no response deadline';
        $due = 0;
    }

    # non-requestor reply
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        $ticket->Correspond( Content => 'we are working on this.' );

        $ticket = RT::Ticket->new( $root );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";

        my $tmp = $ticket->DueObj->Unix;
        ok $tmp > 0, 'Due date is set';
        ok $tmp > $due, "keep in loop due set";
        $due = $tmp;
    }

    # stalling ticket
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        my ($status, $msg) = $ticket->SetStatus('stalled');
        ok $status, 'stalled the ticket';

        $ticket->Load( $id );
        ok !$ticket->DueObj->Unix, 'keep in loop deadline ignored for stalled';
    }

    # non-requestor reply again
    {
        sleep 1;
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        $ticket->Correspond( Content => 'we are still working on this.' );
        $ticket->SetStatus('open');

        $ticket = RT::Ticket->new( $root );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";

        is $ticket->Status, 'open', 'ticket was opened';

        my $tmp = $ticket->DueObj->Unix;
        ok $tmp > 0, 'Due date is set';
        ok $tmp > $due, "keep in loop sligtly moved";
        $due = $tmp;
    }
}

diag 'Check that failing to reply to the requestors is not ignored' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(ServiceAgreements => (
        Default => '2',
        Levels => {
            '2' => {
                Response   => { RealMinutes => 60*2 },
                KeepInLoop => { RealMinutes => 60*4, IgnoreOnStatuses => ['stalled'] },
            },
        },
    ));

    my $root = RT::User->new( $RT::SystemUser );
    $root->LoadByEmail('root@localhost');
    ok $root->id, 'loaded root user';

    # requestor creates
    my $id;
    my $due;
    {
        my $ticket = RT::Ticket->new( $root );
        ($id) = $ticket->Create(
            Queue => 'General',
            Subject => 'xxx',
            Requestor => $root->id,
        );
        ok $id, "created ticket #$id";
        is $ticket->SLA, '2', 'default sla';
        $due = $ticket->DueObj->Unix;
        ok $due > 0, 'response deadline';
    }

    # stalling ticket
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        my ($status, $msg) = $ticket->SetStatus('stalled');
        ok $status, 'stalled the ticket';

        $ticket->Load( $id );
        my $tmp = $ticket->DueObj->Unix;
        ok $tmp, 'response deadline not unset';
        is $tmp, $due, 'due not changed';
    }

    # non-requestor reply
    {
        sleep 1;
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        $ticket->Correspond( Content => 'we are still working on this.' );
        $ticket->SetStatus('open');

        $ticket = RT::Ticket->new( $root );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";

        is $ticket->Status, 'open', 'ticket was opened';

        my $tmp = $ticket->DueObj->Unix;
        ok $tmp > 0, 'Due date is set';
        ok $tmp > $due, "keep in loop is greater than response";
        $due = $tmp;
    }

    # stalling ticket again
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        my ($status, $msg) = $ticket->SetStatus('stalled');
        ok $status, 'stalled the ticket';

        $ticket->Load( $id );
        ok !$ticket->DueObj->Unix, 'keep in loop deadline unset for stalled';
    }
}

diag 'check the ExcludeTimeOnIgnoredStatuses option' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(ServiceAgreements => (
        Default => '2',
        Levels => {
            '2' => {
                Response => { RealMinutes => 60*2, IgnoreOnStatuses => ['stalled'] },
            },
        },
    ));

    my $root = RT::User->new( $RT::SystemUser );
    $root->LoadByEmail('root@localhost');
    ok $root->id, 'loaded root user';

    my $bob =
      RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com', Password => 'password' );
    ok( $bob->Id, "Created test user bob" );
    ok( RT::Test->add_rights( { Principal => 'Privileged', Right => [ qw(CreateTicket ShowTicket ModifyTicket SeeQueue) ] } ),
        'Granted ticket management rights' );

    # requestor creates
    my $id;
    my $due;
    {
        my $ticket = RT::Ticket->new( $bob );
        ($id) = $ticket->Create(
            Queue => 'General',
            Subject => 'xxx',
            Requestor => $bob->id,
        );
        ok $id, "created ticket #$id";
        is $ticket->SLA, '2', 'default sla';
        $due = $ticket->DueObj->Unix;
        ok $due > 0, 'response deadline';
    }

    # stalling ticket
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        my ($status, $msg) = $ticket->SetStatus('stalled');
        ok $status, 'stalled the ticket';

        $ticket->Load( $id );
        ok !$ticket->DueObj->Unix, 'deadline ignored for stalled';
    }

    # requestor reply again
    {
        sleep 1;
        my $ticket = RT::Ticket->new( $bob );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";
        $ticket->Correspond( Content => 'please reopen this ticket, we are good to continue' );
        $ticket->SetStatus('open');

        $ticket = RT::Ticket->new( $root );
        $ticket->Load( $id );
        ok $ticket->id, "loaded ticket #$id";

        is $ticket->Status, 'open', 'ticket was opened';

        my $tmp = $ticket->DueObj->Unix;
        ok $tmp > 0, 'Due date is set';
        ok $tmp == $due, "deadline not changed";
    }

    RT->Config->Set(ServiceAgreements => (
        Default => '2',
        Levels => {
            '2' => {
                Response => { RealMinutes => 60*2, IgnoreOnStatuses => ['stalled'], ExcludeTimeOnIgnoredStatuses => 1 },
            },
        },
    ));
    {
        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        my ($status, $msg) = $ticket->SetStatus('stalled');
        ok $status, 'stalled the ticket';
        ok !$ticket->DueObj->Unix, 'deadline ignored for stalled';
        sleep 1;
        $ticket->SetStatus('open');
        is $ticket->Status, 'open', 'ticket was opened';
        my $tmp = $ticket->DueObj->Unix;
        ok $tmp > 0, 'Due date is set';
        ok $tmp >= $due+1, "deadline slighted moved";
        ok $tmp <= $due+5, "deadline slighted moved but not much";
    }
}

done_testing;
