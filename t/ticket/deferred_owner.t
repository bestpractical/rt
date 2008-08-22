use Test::More  tests => '17';

use strict;
use warnings;

use_ok('RT');
use_ok('RT::Model::Ticket');
use RT::Test;


my $tester = RT::Test->load_or_create_user(
    email => 'tester@localhost',
);
ok $tester && $tester->id, 'loaded or created user';

my $queue = RT::Test->load_or_create_queue( name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

my $owner_role_group = RT::Model::Group->new(current_user => RT->system_user );
$owner_role_group->load_queue_role_group( type => 'owner', queue => $queue->id );
ok $owner_role_group->id, 'loaded owners role group of the queue';

diag "check that deffering owner doesn't regress" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { principal => $tester->principal_object,
          right => [qw(Seequeue ShowTicket CreateTicket OwnTicket)],
        },
        { principal => $owner_role_group->principal_object,
          object => $queue,
          right => [qw(ModifyTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new(current_user => $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as Admincc
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue   => $queue->id,
        owner   => $tester->id,
        admin_cc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    is $ticket->owner, $tester->id, 'correct owner';
    like $ticket->role_group("admin_cc")->member_emails_as_string, qr/root\@localhost/, 'root is there';
}

diag "check that previous trick doesn't work without sufficient rights"
    if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { principal => $tester->principal_object,
          right => [qw(Seequeue ShowTicket CreateTicket OwnTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new(current_user => $tester );
    # tester is owner, owner has right to modify owned tickets,
    # this right is required to set somebody as Admincc
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue   => $queue->id,
        owner   => $tester->id,
        admin_cc => 'root@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    is $ticket->owner, $tester->id, 'correct owner';
    unlike $ticket->role_group("admin_cc")->member_emails_as_string, qr/root\@localhost/, 'root is there';
}

diag "check that deffering owner really works" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { principal => $tester->principal_object,
          right => [qw(Seequeue ShowTicket CreateTicket)],
        },
        { principal => $queue->role_group('cc')->principal_object,
          object => $queue,
          right => [qw(OwnTicket TakeTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new(current_user => $tester );
    # set tester as cc, cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue => $queue->id,
        owner => $tester->id,
        cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    like $ticket->role_group("cc")->member_emails_as_string, qr/tester\@localhost/, 'tester is in the cc list';
    is $ticket->owner, $tester->id, 'tester is also owner';
}

diag "check that deffering doesn't work without correct rights" if $ENV{'TEST_VERBOSE'};
{
    RT::Test->set_rights(
        { principal => $tester->principal_object,
          right => [qw(Seequeue ShowTicket CreateTicket)],
        },
    );
    my $ticket = RT::Model::Ticket->new(current_user => $tester );
    # set tester as cc, cc role group has right to own and take tickets
    my ($tid, $txn_id, $msg) = $ticket->create(
        queue => $queue->id,
        owner => $tester->id,
        cc    => 'tester@localhost',
    );
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};
    ok $tid, "created a ticket";
    like $ticket->role_group("cc")->member_emails_as_string, qr/tester\@localhost/, 'tester is in the cc list';
    isnt $ticket->owner, $tester->id, 'tester is also owner';
}



