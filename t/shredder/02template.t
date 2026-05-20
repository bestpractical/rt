
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 19;
my $test = "RT::Test::Shredder";

diag 'global template' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $template = RT::Template->new( RT->SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $template );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'local template' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $template = RT::Template->new( RT->SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => 'General',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $template );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'template used in scrip' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $template = RT::Template->new( RT->SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => 'General',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($id, $msg) = $scrip->Create(
        Description    => 'my scrip',
        Queue          => 'General',
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => $template->id,
    );
    ok($id, 'created scrip') or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $template );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

# Create a baseline savepoint for the template override tests
$test->create_savepoint('baseline');

diag 'shred queue-level template override directly' if $ENV{TEST_VERBOSE};
{
    # Shred just the queue-level template override, not the whole queue.
    # Global scrips should NOT be affected.

    $test->create_savepoint('clean');

    my $local_template = RT::Template->new( RT->SystemUser );
    my ($id, $msg) = $local_template->Create(
        Name    => 'Correspondence in HTML',
        Queue   => 'General',
        Content => "\nlocal override content",
    );
    ok($id, 'created local template override in General') or diag "error: $msg";

    ok($local_template->IsOverride, 'local template is recognized as override');

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $local_template );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

# Restore DB to baseline so the next test has a fresh state with global scrips
$test->restore_savepoint('baseline');

diag 'queue with queue-level template override of global template, also used by global scrips' if $ENV{TEST_VERBOSE};
{
    # RT has global scrips using "Correspondence in HTML" template by default.
    # Create a queue with a local override of that template.
    # Shredding the queue should NOT shred the global scrips.

    $test->create_savepoint('clean');

    my $queue = RT::Queue->new( RT->SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'override test queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $local_template = RT::Template->new( RT->SystemUser );
    ($id, $msg) = $local_template->Create(
        Name    => 'Correspondence in HTML',
        Queue   => $queue->id,
        Content => "\nlocal override content",
    );
    ok($id, 'created local template override') or diag "error: $msg";

    ok($local_template->IsOverride, 'local template is recognized as override');

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}
