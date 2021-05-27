use strict;
use warnings;

use RT::Test tests => undef;

my $queue_name = "CRSortQueue-$$";
my $queue = RT::Test->load_or_create_queue( Name => $queue_name );

diag "create multiple CRs: B, A and C";

for my $name (qw/B A C/) {
    my $cr = RT::CustomRole->new( RT->SystemUser );
    my ( $ret, $msg ) = $cr->Create( Name => "CR $name", );
    ok( $ret, "Custom Role $name created" );
    ( $ret, $msg ) = $cr->AddToObject( $queue->id );
    ok( $ret, "Added $name to $queue_name: $msg" );
}

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login(), 'Logged in' );

diag "reorder CRs: C, A and B";
{
    $m->get_ok('/Admin/Queues/');
    $m->follow_link_ok( { text => $queue->id } );
    $m->follow_link_ok( { id   => 'page-custom-roles' } );
    my @tmp = ( $m->content =~ /(CR [ABC])/g );
    is_deeply( \@tmp, [ 'CR B', 'CR A', 'CR C' ], 'Order on admin page' );

    $m->follow_link_ok( { text => '[Up]', n => 3 } );
    $m->follow_link_ok( { text => '[Up]', n => 2 } );
    $m->follow_link_ok( { text => '[Up]', n => 3 } );

    @tmp = ( $m->content =~ /(CR [ABC])/g );
    is_deeply( \@tmp, [ 'CR C', 'CR A', 'CR B' ], 'Order on updated admin page' );
}

diag "check ticket create, display and edit pages";
{
    $m->submit_form_ok(
        {   form_name => "CreateTicketInQueue",
            fields    => { Queue => $queue->Name },
        },
        'Get ticket create page'
    );

    my @tmp = ( $m->content =~ /(CR [ABC])/g );
    is_deeply( \@tmp, [ 'CR C', 'CR A', 'CR B' ], 'Order on ticket create page' );

    $m->submit_form_ok(
        {   form_name => "TicketCreate",
            fields    => { Subject => 'test' },
        },
        'Submit ticket create form'
    );
    my ($tid) = ( $m->content =~ /Ticket (\d+) created/i );
    ok $tid, "Created a ticket succesfully";

    @tmp = ( $m->content =~ /(CR [ABC])/g );
    is_deeply( \@tmp, [ 'CR C', 'CR A', 'CR B' ], 'Order on ticket display page' );
    $m->follow_link_ok( { text => 'People' } );

    @tmp = ( $m->content =~ /(CR [ABC])/g );

    # 3 "WatcherTypeEmail1" select boxes and 1 "Current watchers"
    is_deeply( \@tmp, [ ( 'CR C', 'CR A', 'CR B' ) x 4 ], 'Order on ticket people page' );
}

done_testing;
