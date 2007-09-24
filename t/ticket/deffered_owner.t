use RT::Test; use Test::More  tests => '17';

use strict;
use warnings;

use_ok('RT');
use_ok('RT::Model::Ticket');



my $tester = RT::Test->load_or_create_user(
    EmailAddress => 'tester@localhost',
);
ok $tester && $tester->id, 'loaded or Created user';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or Created queue';

my $owner_role_group = RT::Model::Group->new( RT->SystemUser );
$owner_role_group->loadQueueRoleGroup( Type => 'Owner', Queue => $queue->id );
ok $owner_role_group->id, 'loaded owners role group of the queue';

diag "check that defering owner doesn't regress" if $ENV{'TEST_VERBOSE'};
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
    my $ticket = RT::Model::Ticket->new( $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->create(
        Queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    is $ticket->Owner, $tester->id, 'correct owner';
    like $ticket->AdminCcAddresses, qr/root\@localhost/, 'root is an admincc';
}
diag "check that previous trick doesn't work without sufficient rights"
    if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new( $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->create(
        Queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    is $ticket->Owner, $tester->id, 'correct owner';
    unlike $ticket->AdminCcAddresses, qr/root\@localhost/, 'root is there';
}

diag "check that defering owner really works" if $ENV{'TEST_VERBOSE'};
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
    my $ticket = RT::Model::Ticket->new( $tester );
    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        Queue => $queue->id,
        Owner => $tester->id,
        Cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    like $ticket->CcAddresses, qr/tester\@localhost/, 'tester is in the cc list';
    is $ticket->Owner, $tester->id, 'tester is also owner';
}

diag "check that defering doesn't work without correct rights" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(SeeQueue ShowTicket CreateTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new( $tester );
    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        Queue => $queue->id,
        Owner => $tester->id,
        Cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    like $ticket->CcAddresses, qr/tester\@localhost/, 'tester is in the cc list';
    isnt $ticket->Owner, $tester->id, 'tester is also owner';
}



