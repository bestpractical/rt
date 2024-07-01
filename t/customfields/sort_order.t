
use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;
use RT::CustomField;

my $queue_name = "CFSortQueue-$$";
my $queue = RT::Test->load_or_create_queue( Name => $queue_name );
ok($queue && $queue->id, "$queue_name - test queue creation");

diag "create multiple CFs: B, A and C";
my @cfs = ();
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => "CF B",
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field Order created");
    push @cfs, $cf;
}
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => "CF A",
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field Order created");
    push @cfs, $cf;
}
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => "CF C",
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field Order created");
    push @cfs, $cf;
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login( root => 'password' ), 'logged in';

diag "reorder CFs: C, A and B";
{
    $m->get( '/Admin/Queues/' );
    $m->follow_link_ok( {text => $queue->id} );
    $m->follow_link_ok( {id  => 'page-custom-fields-tickets'} );
    my @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF B', 'CF A', 'CF C']);

    $m->follow_link_ok( {text => '[Up]', n => 3} );
    $m->follow_link_ok( {text => '[Up]', n => 2} );
    $m->follow_link_ok( {text => '[Up]', n => 3} );

    @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF C', 'CF A', 'CF B']);
}

diag "check ticket create, display and edit pages";
{
    $m->get_ok( '/Ticket/Create.html?Queue=' . $queue->id, 'go to ticket create page with queue id' );

    my @tmp = ($m->content =~ /(CF [ABC])/g);
    # Names appear twice, one "label for" attribute and one actual label
    is_deeply(\@tmp, ['CF C', 'CF C', 'CF A', 'CF A', 'CF B', 'CF B']);

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
        button => 'SubmitTicket',
    );
    my ($tid) = ($m->content =~ /Ticket (\d+) created/i);
    ok $tid, "created a ticket succesfully";
    
    @tmp = ($m->content =~ /(CF [ABC])/g);
    # Two groups here because inline-edit also adds corresponding labels
    # The first group has just one label, the second doubled like above with "label for" + label
    is_deeply(\@tmp, ['CF C', 'CF A', 'CF B', 'CF C', 'CF C', 'CF A', 'CF A', 'CF B', 'CF B']);
    $m->follow_link_ok( {id => 'page-edit-basics'});

    @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF C', 'CF C', 'CF A', 'CF A', 'CF B', 'CF B']);
}

done_testing;
