use RT::Test; use Test::More  tests => '17';

use strict;
use warnings;

use_ok('RT');
use_ok('RT::Model::Ticket');



my $tester = RT::Test->load_or_create_user(
    email => 'tester@localhost',
);
ok $tester && $tester->id, 'loaded or Created user';

my $queue = RT::Test->load_or_create_queue( name => 'General' );
ok $queue && $queue->id, 'loaded or Created queue';

my $owner_role_group = RT::Model::Group->new(current_user => RT->system_user );
$owner_role_group->load_queue_role_group( type => 'Owner', queue => $queue->id );
ok $owner_role_group->id, 'loaded owners role group of the queue';

diag "check that defering owner doesn't regress" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->principal_object,
          right => [qw(SeeQueue ShowTicket create_ticket OwnTicket)],
        },
        { Principal => $owner_role_group->principal_object,
          object => $queue,
          right => [qw(ModifyTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new(current_user => RT::CurrentUser->new(id => $tester->id) );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    is $ticket->owner, $tester->id, 'correct owner';
    like $ticket->admin_cc_addresses, qr/root\@localhost/, 'root is an admincc';
}
diag "check that previous trick doesn't work without sufficient rights"
    if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->principal_object,
          right => [qw(SeeQueue ShowTicket create_ticket OwnTicket)],
        },
    );
        my $ticket = RT::Model::Ticket->new(current_user => RT::CurrentUser->new(id => $tester->id) );

    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as AdminCc
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue   => $queue->id,
        Owner   => $tester->id,
        AdminCc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    is $ticket->owner, $tester->id, 'correct owner';
    unlike $ticket->admin_cc_addresses, qr/root\@localhost/, 'root is there';
}

diag "check that defering owner really works" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->principal_object,
          right => [qw(SeeQueue ShowTicket create_ticket)],
        },
        { Principal => $queue->cc->principal_object,
          object => $queue,
          right => [qw(OwnTicket TakeTicket)],
        },
    );
        my $ticket = RT::Model::Ticket->new(current_user => RT::CurrentUser->new(id => $tester->id) );

    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue => $queue->id,
        Owner => $tester->id,
        Cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    like $ticket->cc_addresses, qr/tester\@localhost/, 'tester is in the cc list';
    is $ticket->owner, $tester->id, 'tester is also owner';
}

diag "check that defering doesn't work without correct rights" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { Principal => $tester->principal_object,
          right => [qw(SeeQueue ShowTicket create_ticket)],
        },
    );
        my $ticket = RT::Model::Ticket->new(current_user => RT::CurrentUser->new(id => $tester->id) );

    # set tester as Cc, Cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue => $queue->id,
        Owner => $tester->id,
        Cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "Created a ticket";
    like $ticket->cc_addresses, qr/tester\@localhost/, 'tester is in the cc list';
    isnt $ticket->owner, $tester->id, 'tester is also owner';
}



