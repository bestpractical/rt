
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
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
    my $scrip = RT::Scrip->new( RT->SystemUser );
    my ($id, $msg) = $scrip->Create(
        Description    => 'my scrip',
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => 'Blank',
    );
    ok($id, 'created scrip') or diag "error: $msg";
    ok( $scrip->RemoveFromObject(0), 'unapplied scrip from global' );

    # Commit 7d5502ffe makes Scrips not be deleted when a queue is shredded.
    # we need to create the savepoint before applying the scrip so we can test
    # to make sure it's remaining after shredding the queue.
    $test->create_savepoint('clean');

    my $queue = RT::Queue->new( RT->SystemUser );
    ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    # apply the scrip to the queue.
    ($id, $msg) = $scrip->AddToObject( ObjectId => $queue->id );
    ok($id, 'applied scrip to queue') or diag "error: $msg";

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

diag 'queue with custom fields' if $ENV{TEST_VERBOSE};
{
    my $ticket_custom_field = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $ticket_custom_field->Create(
        Name => 'ticket custom field',
        Type => 'Freeform',
        LookupType => RT::Ticket->CustomFieldLookupType,
        MaxValues => '1',
    );
    ok($id, 'created ticket custom field') or diag "error: $msg";

    my $transaction_custom_field = RT::CustomField->new( RT->SystemUser );
    ($id, $msg) = $transaction_custom_field->Create(
        Name => 'transaction custom field',
        Type => 'Freeform',
        LookupType => RT::Transaction->CustomFieldLookupType,
        MaxValues => '1',
    );
    ok($id, 'created transaction custom field') or diag "error: $msg";

    my $queue_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $queue_custom_field->Create(
        Name       => 'queue custom field',
        Type       => 'Freeform',
        LookupType => RT::Queue->CustomFieldLookupType,
        MaxValues  => '1',
    );
    ok( $id, 'created queue custom field' ) or diag "error: $msg";

    my $article_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $article_custom_field->Create(
        Name       => 'article custom field',
        Type       => 'Freeform',
        LookupType => RT::Article->CustomFieldLookupType,
        MaxValues  => '1',
    );
    ok( $id, 'created article custom field' ) or diag "error: $msg";

    my $asset_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $asset_custom_field->Create(
        Name       => 'asset custom field',
        Type       => 'Freeform',
        LookupType => RT::Catalog->CustomFieldLookupType,
        MaxValues  => '1',
    );
    ok( $id, 'created asset custom field' ) or diag "error: $msg";

    # By default there are 2 queues and 1 class/catalog created.  So we need
    # to create 1 extra class/catalog to catch up the queue id.
    my $class = RT::Class->new( RT->SystemUser );
    ok( $class->Create( Name => "class $_" ), "created class $_" ) for 2 .. 3;
    is( $class->id, 3, 'Loaded class with the same to-be-created queue id=3' );
    ( $id, $msg ) = $article_custom_field->AddToObject($class);
    ok( $id, 'applied article cf to class' ) or diag "error: $msg";

    my $catalog = RT::Catalog->new( RT->SystemUser );
    ok( $catalog->Create( Name => "catalog $_" ), "created catalog $_" ) for 2 .. 3;
    is( $catalog->id, 3, 'Loaded catalog with the same to-be-created queue id=3' );
    ( $id, $msg ) = $asset_custom_field->AddToObject($catalog);
    ok( $id, 'applied asset cf to catalog' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $queue = RT::Queue->new( RT->SystemUser );
    ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";
    is($id, 3, 'created queue id=3');

    # apply the custom fields to the queue.
    ($id, $msg) = $ticket_custom_field->AddToObject( $queue );
    ok($id, 'applied ticket cf to queue') or diag "error: $msg";

    ($id, $msg) = $transaction_custom_field->AddToObject( $queue );
    ok($id, 'applied txn cf to queue') or diag "error: $msg";

    ( $id, $msg ) = $queue_custom_field->AddToObject($queue);
    ok( $id, 'applied queue cf to queue' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $queue );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

done_testing;
