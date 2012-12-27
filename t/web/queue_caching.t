use strict;
use warnings;
use RT::Test tests => 48;

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

diag("Rename the original queue, make sure the name change is uncached");
{
    ok($original_test_queue->SetName("Name Change $$"));
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
check_queues($a_m,[$original_test_queue->Id],[$original_test_queue->Name]);

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


# takes a WWW::Mech object and two optional arrayrefs of queue ids and names
# compares the list of ids and names to the dropdown of Queues for the New Ticket In form
sub check_queues {
    my ($browser, $queue_id_list, $queue_name_list) = @_;
    $browser->get_ok($baseurl,"Navigated to homepage");
    ok(my $form = $browser->form_name('CreateTicketInQueue'), "Found New Ticket In form");
    ok(my $queuelist = $form->find_input('Queue','option'), "Found queue select");

    my @queue_ids = $queuelist->possible_values;
    my @queue_names = $queuelist->value_names;

    my $full_queue_list = internal_queues();
    $queue_id_list = [keys %$full_queue_list] unless $queue_id_list;
    $queue_name_list = [values %$full_queue_list] unless $queue_name_list;
    is_deeply([sort @queue_ids],[sort @$queue_id_list],
              "Queue list contains the expected queue ids");
    is_deeply([sort @queue_names],[sort @$queue_name_list],
              "Queue list contains the expected queue namess");
}
