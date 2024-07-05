
use strict;
use warnings;

use RT::Test tests => undef, selenium => 1;

my ( $url, $s ) = RT::Test->started_ok;

$s->login();

{
    $s->goto_create_ticket(1);

    my $subject = Encode::decode( "UTF-8", "I18N Web Testing Subject æøå" );
    my $content = Encode::decode( "UTF-8", "I18N Web Testing Content æøå" );
    $s->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => {
                Subject => $subject,
                Content => $content,
            },
            button => 'SubmitTicket',
        },
        'Create ticket'
    );

    # Find an element in history to implicitly wait for the delayed history load
    $s->find_element(q{//div[contains(@class, 'transaction')]});
    $s->text_contains( $content, 'Found the content' );

    {
        my $ticket  = RT::Test->last_ticket;
        my $content = $ticket->Transactions->First->Content;
        like( $content, qr{$content}, 'content is there, API check' );
        is( $ticket->Subject, $subject, 'subject is correct, API check' );
    }
}

# Update time worked in hours
{
    $s->follow_link_ok( { text => 'Basics', menu => '#page-edit' } );
    $s->submit_form_ok(
        {
            form_name => 'TicketModify',
            fields    => {
                TimeWorked             => 5,
                'TimeWorked-TimeUnits' => 'hours',
            },
            button => 'SubmitTicket',
        },
        'Update ticket TimeWorked'
    );

    $s->text_contains( "5 hours", "5 hours is displayed" );
    $s->text_contains( "300 min", "but minutes is also" );
}

{
    $s->get_ok( $url . "/static/js/i18n.js" );
    my $file = RT::Test::get_relocatable_file( File::Spec->catfile(qw(.. .. share static js i18n.js)) );
    # + 1 as get_body doesn't contain the new line before EOF.
    is( length( $s->get_body ) + 1, -s $file, "got a file of the correct size ($file)", );
}

{
    my $queue = RT::Test->load_or_create_queue( Name => 'foo&bar' );
    $s->goto_create_ticket( $queue->id );
    $s->title_is('Create a new ticket in foo&bar');
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
    $s->goto_create_ticket($queue);
    $s->title_is('Create a new ticket in General');
    $s->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );

    $s->text_like(qr/Ticket \d+ created in queue/);

    my $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 123, 'CF value is set' );

    $s->goto_create_ticket($queue);
    $s->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );
    $s->text_contains("'123' is not a unique value");
    $s->text_unlike(qr/Ticket \d+ created in queue/);

    $s->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '456' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 456'
    );
    $s->text_like(qr/Ticket \d+ created in queue/);
    $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 456, 'CF value is set' );
    my $ticket_id = $ticket->Id;

    $s->follow_link_ok( { text => 'Basics', menu => '#page-edit' } );
    $s->submit_form_ok(
        {
            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '123' },
        },
        'Update ticket with cf value 123'

    );
    $s->text_contains("'123' is not a unique value");
    $s->text_lacks( 'External ID 456 changed to 123', 'Can not change to an existing value' );

    $s->submit_form_ok(
        {

            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '789' },
        },
        'Update ticket with cf value 789'
    );
    $s->text_contains( 'External ID 456 changed to 789', 'Changed cf to a new value' );

    $s->submit_form_ok(
        {

            form_name => 'TicketModify',
            fields    => { "Object-RT::Ticket-$ticket_id-CustomField-$cf_id-Value" => '456' },
        },
        'Update ticket with cf value 456'
    );
    $s->text_contains( 'External ID 789 changed to 456', 'Changed cf back to old value' );
}

$s->logout;

done_testing;
