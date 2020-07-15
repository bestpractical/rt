use strict;
use warnings;

use RT::Test tests => undef;

# create ticket in general queue
# this ticket will display the portlet for the other queue, with the other ticket in it
my $ticket_one = RT::Test->create_ticket(
    Subject => 'test ticket in General queue',
    Queue   => 'General'
);

# create test queue and test ticket in it
my $queue_name = 'test queue';
my $queue_two  = RT::Test->load_or_create_queue(
    Name        => $queue_name,
    Description => $queue_name
);
my $ticket_two = RT::Test->create_ticket(
    Subject => 'test ticket in "' . $queue_name . '" queue',
    Queue   => $queue_name
);

# change config to load new queue portlet in general
# this isn't exercising limiting to a specific link relationship set such as 'HasMember', 'MemberOf', or 'RefersTo'; just 'All'
RT->Config->Set(
    LinkedQueuePortlets => (
        General => [
            { $queue_name => [ 'All' ] },
        ],
    ),
);

# verify new queue portlet is present in ticket in general
my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

my $linked_queue_class = 'linked-queue';
$m->get_ok( "/Ticket/Display.html?id=" . $ticket_one->Id );
$m->content_contains( $linked_queue_class,
    'ticket in "General" queue contains linked queue portlet for "' . $queue_name . '" queue' );

# link tickets so the ticket shows up in the linked queue portlet
ok( $ticket_one->AddLink( Type => 'RefersTo', Target => $ticket_two->Id ),
    'added RefersTo link for ticket in "General" queue to ticket in "' . $queue_name . '" queue' );

$m->get_ok( "/Ticket/Display.html?id=" . $ticket_one->Id );
is( $m->dom->find(".$linked_queue_class .collection-as-table a")->first->attr('href'),
    '/Ticket/Display.html?id=' . $ticket_two->Id,
    'linked queue portlet contains link to ticket in "' . $queue_name . '" queue' );

# TODO:
# limit the linked queue configuration to only specific link relationships to ensure only those tickets show up in the portlet

done_testing();
