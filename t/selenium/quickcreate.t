use strict;
use warnings;
use Test::Deep;
use RT::Test tests => undef, selenium => 1;

RT->Config->Set('DisplayTicketAfterQuickCreate' => 0);

my ($baseurl, $s) = RT::Test->started_ok;

ok($s->login, 'logged in');

diag "Create ticket with quick create";
{
    $s->submit_form_ok(
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
    my $dom = $s->dom;
    my $message = $dom->find('.jGrowl-message')->map('text')->to_array;
    like( $message->[0], qr/Ticket \d+ created in queue \'General\'/, 'jGrowl message found' );
    $s->close_jgrowl;
    $s->current_url_is( $baseurl . '/', 'Still in homepage' );
    $s->current_url_isnt( "$baseurl/Ticket/Display.html", 'Not on ticket display page' );
}

diag "Test redirect to ticket after create";
{
    $s->get_ok($baseurl . '/Prefs/Other.html');
    $s->submit_form_ok(
        {
            form_name => 'ModifyPreferences',
            fields    => { 'DisplayTicketAfterQuickCreate' => 1, },
            button => 'Update',
        },
        'Change preference to display ticket after create'
    );

    $s->content_contains( 'Preferences saved', 'enabled DisplayTicketAfterQuickCreate' );
    $s->get($baseurl);

    $s->submit_form_ok(
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
    $s->content_like( qr/Ticket \d+ created in queue \'General\'/, 'Created message found' );
    $s->current_url_like( qr/$baseurl\/Ticket\/Display.html\?id=\d+\&results=\w+/, 'On new ticket display page' );
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
    $s->get($baseurl);

    $s->submit_form_ok(
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
    $s->current_url_like( qr/^$baseurl\/Ticket\/Create.html/, 'Redirected to ticket create page' );
    $s->content_like( qr/Please finish by using the normal ticket creation page/, 'Got redirect message' );
    $s->content_contains("Yaks: Input must match", "Found CF validation error Yaks");
}

$s->logout;

done_testing;
