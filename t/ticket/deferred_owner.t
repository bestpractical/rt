
use strict;
use warnings;

use RT::Test tests => 18;
use_ok('RT');
use_ok('RT::Ticket');
use Test::Warn;


my $tester = RT::Test->load_or_create_user(
    EmailAddress => 'tester@localhost',
);
ok $tester && $tester->id, 'loaded or created user';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

my $owner_role_group = RT::Group->new( $RT::SystemUser );
$owner_role_group->LoadQueueRoleGroup( Type => 'Owner', Queue => $queue->id );
ok $owner_role_group->id, 'loaded owners role group of the queue';

diag "check that deffering owner doesn't regress" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket)],
        },
        { Principal => $owner_role_group->PrincipalObj,
          Object => $queue,
          Right => [qw(ModifyTicket)],
        },
    );
    my $ticket = RT::Ticket->new( $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->Create(
        Queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    is $ticket->Owner, $tester->id, 'correct owner';
    like $ticket->AdminCcAddresses, qr/root\@localhost/, 'root is there';
}

diag "check that previous trick doesn't work without sufficient rights"
    if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket)],
        },
    );
    my $ticket = RT::Ticket->new( $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->Create(
        Queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    is $ticket->Owner, $tester->id, 'correct owner';
    unlike $ticket->AdminCcAddresses, qr/root\@localhost/, 'root is there';
}

diag "check that deffering owner really works" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket)],
        },
        { Principal => $queue->Cc->PrincipalObj,
          Object => $queue,
          Right => [qw(OwnTicket TakeTicket)],
        },
    );
    my $ticket = RT::Ticket->new( $tester );
    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $tester->id,
        Cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    like $ticket->CcAddresses, qr/tester\@localhost/, 'tester is in the cc list';
    is $ticket->Owner, $tester->id, 'tester is also owner';
}

diag "check that deffering doesn't work without correct rights" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket)],
        },
    );

    my $ticket = RT::Ticket->new( $tester );
    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg);
    warning_like {
        ($tid, $txn_id, $msg) = $ticket->Create(
            Queue => $queue->id,
            Owner => $tester->id,
            Cc    => 'tester@localhost',
        );
    } qr/User .* was proposed as a ticket owner but has no rights to own tickets in General/;

    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    like $ticket->CcAddresses, qr/tester\@localhost/, 'tester is in the cc list';
    isnt $ticket->Owner, $tester->id, 'tester is also owner';
}



