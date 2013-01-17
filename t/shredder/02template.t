
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 10;
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
