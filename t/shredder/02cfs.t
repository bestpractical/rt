
use strict;
use warnings;

use Test::Deep;
use File::Spec;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

$test->create_savepoint('clean');

my $cf = RT::Test->load_or_create_custom_field(
    Name        => "Favorite Color",
    LookupType  => "RT::Queue-RT::Ticket",
    Type        => "FreeformSingle",
);
ok $cf->id, "Created ticket CF";
$test->create_savepoint('clean_with_cf');

diag 'global ticket custom field';
{
    my $global_queue = RT::Queue->new(RT->SystemUser);
    my ($ok, $msg) = $cf->AddToObject($global_queue);
    ok $ok, "Added ticket CF globally: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $cf );
    $shredder->WipeoutAll;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue-specific ticket custom field';
{
    $test->restore_savepoint('clean_with_cf');
    my $general = RT::Test->load_or_create_queue( Name => 'General' );
    my ($ok, $msg) = $cf->AddToObject($general);
    ok $ok, "Added ticket CF to General queue: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $cf );
    $shredder->WipeoutAll;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'global ticket custom field + ticket';
{
    $test->restore_savepoint('clean');
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );
    $test->create_savepoint('clean_with_ticket');

    my $cf = RT::Test->load_or_create_custom_field(
        Name       => "Favorite Color",
        LookupType => "RT::Queue-RT::Ticket",
        Type       => "FreeformSingle",
    );
    my $global_queue = RT::Queue->new(RT->SystemUser);
    my ($ok, $msg) = $cf->AddToObject($global_queue);
    ok $ok, "Added ticket CF globally: $msg";

    $ticket->AddCustomFieldValue( Field => $cf->Name, Value => 'foo' );

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $cf );
    $shredder->WipeoutAll;
    cmp_deeply( $test->dump_current_and_savepoint('clean_with_ticket'), "current DB equal to savepoint");
}

done_testing;
