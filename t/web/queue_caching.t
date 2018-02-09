use strict;
use warnings;
use RT::Test tests => undef;

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

diag( "Test a user who has only CreateTicket right" );
{
    my $user_b = RT::Test->load_or_create_user(
        Name     => 'user_b',
        Password => 'password',
    );
    ok $user_b && $user_b->id, 'loaded or created user';

    ok(
        RT::Test->add_rights(
            { Principal => $user_b, Right => [qw(CreateTicket)] },
        ),
        'add global queue CreateTicket right'
    );

    my $b_m = RT::Test::Web->new;
    ok $b_m->login( 'user_b', 'password' ), 'logged in as user B';

    check_queues( $b_m, [], [] );
}

diag( "Test a user who has only SeeQueue right" );
{
    my $user_c = RT::Test->load_or_create_user(
        Name     => 'user_c',
        Password => 'password',
    );
    ok $user_c && $user_c->id, 'loaded or created user';

    ok(
        RT::Test->add_rights(
            { Principal => $user_c, Right => [qw(SeeQueue)] },
        ),
        'add global queue SeeQueue right'
    );

    my $c_m = RT::Test::Web->new;
    ok $c_m->login( 'user_c', 'password' ), 'logged in as user C';

    check_queues( $c_m, [], [] );
}

diag( "Test a user starting with ShowTicket and ModifyTicket rights" );
{
    my $user_d = RT::Test->load_or_create_user(
        Name     => 'user_d',
        Password => 'password',
    );
    ok $user_d && $user_d->id, 'loaded or created user';

    ok(
        RT::Test->add_rights(
            { Principal => $user_d, Right => [qw(ShowTicket ModifyTicket)] },
        ),
        'add global queue ShowTicket/ModifyTicket rights'
    );

    my $d_m = RT::Test::Web->new;
    ok $d_m->login( 'user_d', 'password' ), 'logged in as user D';

    for my $queue ( 1, $original_test_queue->id ) {
        RT::Test->create_ticket(
            Queue   => $queue,
            Subject => "Ticket in queue $queue",
        );

        check_queues( $d_m, [], [] );

        $d_m->follow_link_ok( { text => "Ticket in queue $queue" } );
        $d_m->follow_link_ok( { text => 'Basics' } );
        check_queues( $d_m, [$queue], ["#$queue"], $d_m->uri, 'TicketModify' );
    }

    ok(
        RT::Test->add_rights(
            { Principal => $user_d, Right => [qw(SeeQueue)] },
        ),
        'add global queue SeeQueue right'
    );

    for my $queue ( 1, $original_test_queue->id ) {

        check_queues( $d_m, [], [] );

        $d_m->follow_link_ok( { text => "Ticket in queue $queue" } );
        $d_m->follow_link_ok( { text => 'Basics' } );
        check_queues( $d_m, undef, undef, $d_m->uri, 'TicketModify' );
    }

    ok(
        RT::Test->add_rights(
            { Principal => $user_d, Right => [qw(CreateTicket)] },
        ),
        'add global queue CreateTicket right'
    );

    for my $queue ( 1, $original_test_queue->id ) {
        check_queues( $d_m );
        $d_m->follow_link_ok( { text => "Ticket in queue $queue" } );
        $d_m->follow_link_ok( { text => 'Basics' } );
        check_queues( $d_m, undef, undef, $d_m->uri, 'TicketModify' );
    }
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
    my ($browser, $queue_id_list, $queue_name_list, $url, $form_name) = @_;
    $url ||= $baseurl;
    $form_name ||= 'CreateTicketInQueue';

    $browser->get_ok( $url, "Navigated to $url" );
    ok( my $form = $browser->form_name( $form_name ), "Found form $form_name" );
    my ( @queue_ids, @queue_names );
    if ( !$queue_id_list || @$queue_id_list > 0 ) {
        ok(my $queuelist = $form->find_input('Queue','option'), "Found queue select");
        @queue_ids = $queuelist->possible_values;
        @queue_names = $queuelist->value_names;
    }
    else {
        ok( !$form->find_input( 'Queue', 'option' ), "No queue select options" );
    }

    my $full_queue_list = internal_queues();
    $queue_id_list = [keys %$full_queue_list] unless $queue_id_list;
    $queue_name_list = [values %$full_queue_list] unless $queue_name_list;
    is_deeply([sort @queue_ids],[sort @$queue_id_list],
              "Queue list contains the expected queue ids");
    is_deeply([sort @queue_names],[sort @$queue_name_list],
              "Queue list contains the expected queue names");
}

done_testing;
