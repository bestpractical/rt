
use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;

# get the top page
{
    $agent->get($url);
    is ($agent->status, 200, "Loaded a page");
}

# test a login
{
    $agent->login('root' => 'password');
    # the field isn't named, so we have to click link 0
    is( $agent->status, 200, "Fetched the page ok");
    $agent->content_contains("Logout", "Found a logout link");
}

{
    $agent->goto_create_ticket(1);
    is ($agent->status, 200, "Loaded Create.html");
    $agent->form_name('TicketCreate');
    my $string = Encode::decode("UTF-8","I18N Web Testing æøå");
    $agent->field('Subject' => "Ticket with utf8 body");
    $agent->field('Content' => $string);
    ok($agent->click('SubmitTicket'), "Created new ticket with $string as Content");
    $agent->content_contains($string, "Found the content");
    ok($agent->{redirected_uri}, "Did redirection");

    {
        my $ticket = RT::Test->last_ticket;
        my $content = $ticket->Transactions->First->Content;
        like(
            $content, qr{$string},
            'content is there, API check'
        );
    }
}

{
    $agent->goto_create_ticket(1);
    is ($agent->status, 200, "Loaded Create.html");
    $agent->form_name('TicketCreate');

    my $string = Encode::decode( "UTF-8","I18N Web Testing æøå");
    $agent->field('Subject' => $string);
    $agent->field('Content' => "Ticket with utf8 subject");
    ok($agent->click('SubmitTicket'), "Created new ticket with $string as Content");
    $agent->content_contains($string, "Found the content");
    ok($agent->{redirected_uri}, "Did redirection");

    {
        my $ticket = RT::Test->last_ticket;
        is(
            $ticket->Subject, $string,
            'subject is correct, API check'
        );
    }
}

# Update time worked in hours
{
    $agent->follow_link( text_regex => qr/Basics/ );
    $agent->submit_form( form_name => 'TicketModify',
        fields => { TimeWorked => 5, 'TimeWorked-TimeUnits' => "hours" }
    );

    $agent->content_contains("5 hours", "5 hours is displayed");
    $agent->content_contains("300 min", "but minutes is also");
}


$agent->get( $url."static/images/test.png" );
my $file = RT::Test::get_relocatable_file(
  File::Spec->catfile(
    qw(.. .. share static images test.png)
  )
);
is(
    length($agent->content),
    -s $file,
    "got a file of the correct size ($file)",
);

{
    my $queue = RT::Test->load_or_create_queue( Name => 'foo&bar' );
    $agent->goto_create_ticket( $queue->id );
    is( $agent->status, 200, "Loaded Create.html" );
    $agent->title_is('Create a new ticket in foo&bar');
}

diag "test custom field unique values";
{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue';

    my $cf = RT::Test->load_or_create_custom_field(
        Name         => 'External ID',
        Queue        => 'General',
        Type         => 'FreeformSingle',
        UniqueValues => 1,
    );
    my $cf_id = $cf->Id;

    $agent->goto_create_ticket($queue);
    $agent->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );

    $agent->text_like(qr/Ticket \d+ created in queue/);
    my $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 123, 'CF value is set' );

    $agent->goto_create_ticket($queue);
    $agent->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );
    $agent->text_contains("'123' is not a unique value");
    $agent->text_unlike(qr/Ticket \d+ created in queue/);

    $agent->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '456' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 456'
    );
    $agent->text_like(qr/Ticket \d+ created in queue/);
    $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 456, 'CF value is set' );
    my $ticket_id = $ticket->Id;

    $agent->follow_link_ok( { text => 'Basics' } );
    $agent->submit_form_ok(
        {
            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '123' },
        },
        'Update ticket with cf value 123'

    );
    $agent->text_contains("'123' is not a unique value");
    $agent->text_lacks( 'External ID 456 changed to 123', 'Can not change to an existing value' );

    $agent->submit_form_ok(
        {

            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '789' },
        },
        'Update ticket with cf value 789'
    );
    $agent->text_contains( 'External ID 456 changed to 789', 'Changed cf to a new value' );

    $agent->submit_form_ok(
        {

            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '456' },
        },
        'Update ticket with cf value 456'
    );
    $agent->text_contains( 'External ID 789 changed to 456', 'Changed cf back to old value' );
}

done_testing;
