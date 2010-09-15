use strict;
use warnings;
use RT::Test tests => 6;

# make an initial queue, so we have more than 1
new_queue("Test$$");

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag("Check for 2 existing queues being visible") if $ENV{TEST_VERBOSE};
{
ok(my $form = $m->form_name('CreateTicketInQueue'), "Found New Ticket In form");
ok(my $queuelist = $form->find_input('Queue','option'), "Found queue select");
my @queues = $queuelist->possible_values;

my $queue_list = internal_queues();
is_deeply([sort @queues],[sort keys %$queue_list], "Queue list contains the expected queues");
}

sub new_queue {
    my $name = shift;
    my $new_queue = RT::Queue->new($RT::SystemUser);
    ok($new_queue->Create( Name => $name, Description => "Testing for $name queue" ), "Created queue ".$new_queue->Name);
    return $new_queue;
}

sub internal_queues {
    my $internal_queues = RT::Queues->new($RT::SystemUser);
    $internal_queues->Limit(FIELD => 'Disabled', VALUE => 0);
    my $queuelist;
    while ( my $q = $internal_queues->Next ) {
        $queuelist->{$q->Id} = $q->Name;
    }
    return $queuelist;
}

