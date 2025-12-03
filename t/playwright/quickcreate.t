use strict;
use warnings;
use Test::Deep;
use RT::Test tests => undef, playwright => 1;

RT->Config->Set('DisplayTicketAfterQuickCreate' => 0);

my ($baseurl, $p) = RT::Test->started_ok;

ok($p->login, 'logged in');

diag "Create ticket with quick create";
{
    $p->submit_form_ok(
        {
            form_name => 'QuickCreate',
            fields    => {
                Subject => 'Test quick create',
                Content => 'This is from quick create',
            },
            button => 'QuickCreateSubmit',
        },
        'Create ticket with Quick Create'
    );
    $p->wait_for_notifications();
    my $dom = $p->dom;
    my $message = $dom->find('.jGrowl-message')->map('text')->to_array;
    like( $message->[0], qr/Ticket \d+ created in queue \'General\'/, 'jGrowl message found' );
    $p->close_jgrowl;
    $p->current_url_is( $baseurl . '/', 'Still in homepage' );
    $p->current_url_isnt( "$baseurl/Ticket/Display.html", 'Not on ticket display page' );
}

diag "Test redirect to ticket after create";
{
    $p->get_ok($baseurl . '/Prefs/Other.html');
    $p->submit_form_ok(
        {
            form_name => 'ModifyPreferences',
            fields    => { 'DisplayTicketAfterQuickCreate' => 1, },
            button => 'Update',
        },
        'Change preference to display ticket after create'
    );

    $p->content_contains( 'Preferences saved', 'enabled DisplayTicketAfterQuickCreate' );
    $p->get($baseurl);

    $p->submit_form_ok(
        {
            form_name => 'QuickCreate',
            fields    => {
                Subject => 'Test quick create',
                Content => 'This is from quick create',
            },
            button => 'QuickCreateSubmit',
        },
        'Create ticket with Quick Create'
    );

    # There might be a lag in getting the expected content back.
    my $message_found = 0;
    for ( my $i = 0; $i < 6; $i++ ) {
        sleep 0.5;
        if ( $p->{page}->content() =~ qr/Ticket \d+ created in queue \'General\'/ ) {
            $message_found = 1;
            last;
        }
    }
    ok( $message_found, 'Created message found' );

    $p->current_url_like( qr/$baseurl\/Ticket\/Display.html\?id=\d+\&results=\w+/, 'On new ticket display page' );
}

my $cf_yaks = RT::Test->load_or_create_custom_field(
    Name        => 'Yaks',
    Type        => 'FreeformSingle',
    Pattern     => '(?#Digits)^\d+$',
    Queue       => 0,
    LookupType  => 'RT::Queue-RT::Ticket',
);
ok $cf_yaks && $cf_yaks->id, "Created CF with Pattern";

diag 'Test redirect with custom fields';
{
    $p->get($baseurl);

    $p->submit_form_ok(
        {
            form_name => 'QuickCreate',
            fields    => {
                Subject => 'Test quick create',
                Content => 'This is from quick create',
            },
            button => 'QuickCreateSubmit',
        },
        'Create ticket with Quick Create'
    );
    $p->current_url_like( qr/^$baseurl\/Ticket\/Create.html/, 'Redirected to ticket create page' );
    $p->content_like( qr/Please finish by using the normal ticket creation page/, 'Got redirect message' );
    $p->content_contains("Yaks: Input must match", "Found CF validation error Yaks");
}

$p->logout;

done_testing;
