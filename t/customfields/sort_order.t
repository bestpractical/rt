
use strict;
use warnings;

use RT::Test tests => 20;
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
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => $queue->Name },
    );

    my @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF C', 'CF A', 'CF B']);

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    my ($tid) = ($m->content =~ /Ticket (\d+) created/i);
    ok $tid, "created a ticket succesfully";
    
    @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF C', 'CF A', 'CF B']);
    $m->follow_link_ok( {id => 'page-basics'});

    @tmp = ($m->content =~ /(CF [ABC])/g);
    is_deeply(\@tmp, ['CF C', 'CF A', 'CF B']);
}

