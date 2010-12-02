use strict;
use warnings;
use RT::Test tests => 36;

# make an initial queue, so we have more than 1
my $original_test_queue = new_queue("Test$$");

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag("Check for 2 existing queues being visible");
{
    check_queues($m);
}

diag("Add a new queue, which won't show up until we fix the cache");
{
    new_queue("New Test $$");
    check_queues($m);
}

diag("Disable an existing queue, it should stop appearing in the list");
{
    ok($original_test_queue->SetDisabled(1));
    check_queues($m);
}

diag("Bring back a disabled queue");
{
    ok($original_test_queue->SetDisabled(0));
    check_queues($m);
}

diag("Test a user who has more limited rights Queues");
{

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

ok( RT::Test->set_rights(
        { Principal => $user_a, Right => [qw(SeeQueue CreateTicket)], Object => $original_test_queue },
), 'Allow user a to see the testing queue');

my $a_m = RT::Test::Web->new;
ok $a_m->login('user_a', 'password'), 'logged in as user A';

# check that they see a single queue
check_queues($a_m,[$original_test_queue->Id]);

ok( RT::Test->add_rights(
        { Principal => $user_a, Right => [qw(SeeQueue CreateTicket)] },
), 'add global queue viewing rights');

check_queues($a_m);

}

sub new_queue {
    my $name = shift;
    my $new_queue = RT::Queue->new(RT->SystemUser);
    ok($new_queue->Create( Name => $name, Description => "Testing for $name queue" ), "Created queue ".$new_queue->Name);
    return $new_queue;
}

sub internal_queues {
    my $internal_queues = RT::Queues->new(RT->SystemUser);
    $internal_queues->Limit(FIELD => 'Disabled', VALUE => 0);
    my $queuelist;
    while ( my $q = $internal_queues->Next ) {
        $queuelist->{$q->Id} = $q->Name;
    }
    return $queuelist;
}


# takes a WWW::Mech object and an optional arrayref of queue ids
# compares the list of ids to the dropdown of Queues for the New Ticket In form
sub check_queues {
    my $browser = shift;
    my $queue_list = shift;
    $browser->get_ok($baseurl,"Navigated to homepage");
    ok(my $form = $browser->form_name('CreateTicketInQueue'), "Found New Ticket In form");
    ok(my $queuelist = $form->find_input('Queue','option'), "Found queue select");
    my @queues = $queuelist->possible_values;

    $queue_list = [keys %{internal_queues()}] unless $queue_list;
    is_deeply([sort @queues],[sort @$queue_list], "Queue list contains the expected queues");
}
