
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 21;
my $test = "RT::Test::Shredder";

diag 'simple queue' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $queue = RT::Queue->new( RT->SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with scrip' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $queue = RT::Queue->new( RT->SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($id, $msg) = $scrip->Create(
        Description    => 'my scrip',
        Queue          => $queue->id,
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => 'Blank',
    );
    ok($id, 'created scrip') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with template' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $queue = RT::Queue->new( RT->SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $template = RT::Template->new( RT->SystemUser );
    ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => $queue->id,
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a right granted' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $queue = RT::Queue->new( RT->SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup('Everyone');
    ok($group->id, 'loaded group');

    ($id, $msg) = $group->PrincipalObj->GrantRight(
        Right  => 'CreateTicket',
        Object => $queue,
    );
    ok($id, 'granted right') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a watcher' if $ENV{TEST_VERBOSE};
{
# XXX, FIXME: if uncomment these lines then we'll get 'Bizarre...'
#    $test->create_savepoint('clean');
    my $group = RT::Group->new( RT->SystemUser );
    my ($id, $msg) = $group->CreateUserDefinedGroup(Name => 'my group');
    ok($id, 'created group') or diag "error: $msg";

    $test->create_savepoint('bqcreate');
    my $queue = RT::Queue->new( RT->SystemUser );
    ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    ($id, $msg) = $queue->AddWatcher(
        Type   => 'Cc',
        PrincipalId => $group->id,
    );
    ok($id, 'added watcher') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('bqcreate'), "current DB equal to savepoint");

#    $shredder->PutObjects( Objects => $group );
#    $shredder->WipeoutAll;
#    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}
