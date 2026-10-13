
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

diag "custom field values changed by someone else while a form is open";
{
    my $single = RT::Test->load_or_create_custom_field(
        Name  => 'Customer Priority',
        Queue => 'General',
        Type  => 'FreeformSingle',
    );
    my $select = RT::Test->load_or_create_custom_field(
        Name  => 'Severity',
        Queue => 'General',
        Type  => 'SelectSingle',
    );
    for my $value (qw/low medium high/) {
        my ( $ok, $msg ) = $select->AddValue( Name => $value );
        ok( $ok, "Added Severity value $value" ) or diag $msg;
    }
    my $multiple = RT::Test->load_or_create_custom_field(
        Name  => 'Affected Hosts',
        Queue => 'General',
        Type  => 'FreeformMultiple',
    );

    my $ticket = RT::Test->create_ticket(
        Queue   => 'General',
        Subject => 'Test concurrent custom field updates',
    );
    my $ticket_id = $ticket->Id;

    my %input = (
        single   => "Object-RT::Ticket-$ticket_id-CustomField-" . $single->Id . "-Value",
        select   => "Object-RT::Ticket-$ticket_id-CustomField-" . $select->Id . "-Values",
        multiple => "Object-RT::Ticket-$ticket_id-CustomField-" . $multiple->Id . "-Values",
    );

    my $set_values = sub {
        my %values = @_;
        my $staff = RT::Ticket->new( RT->SystemUser );
        $staff->Load($ticket_id);
        for my $cf ( $single, $select, $multiple ) {
            my $new = $values{ $cf->Name };
            for my $old ( @{ $staff->CustomFieldValues( $cf->Id )->ItemsArrayRef } ) {
                my ( $ok, $msg ) = $staff->DeleteCustomFieldValue( Field => $cf->Id, ValueId => $old->Id );
                ok( $ok, 'Deleted ' . $cf->Name . ' value' ) or diag $msg;
            }
            for my $value (@$new) {
                my ( $ok, $msg ) = $staff->AddCustomFieldValue( Field => $cf->Id, Value => $value );
                ok( $ok, 'Set ' . $cf->Name . " to $value" ) or diag $msg;
            }
        }
    };

    my $values_are = sub {
        my ( $expected, $description ) = @_;
        my $current = RT::Ticket->new( RT->SystemUser );
        $current->Load($ticket_id);
        my %got = map {
            $_->Name => [ sort map { $_->Content } @{ $current->CustomFieldValues( $_->Id )->ItemsArrayRef } ]
        } $single, $select, $multiple;
        is_deeply( \%got, $expected, $description );
    };

    $set_values->( 'Customer Priority' => ['P3'], 'Severity' => ['low'], 'Affected Hosts' => ['alpha'] );

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    my $form = $agent->form_name('TicketModifyAll');
    is( $form->value( $input{single} ),   'P3',    'Form shows Customer Priority P3' );
    is( $form->value( $input{select} ),   'low',   'Form shows Severity low' );
    is( $form->value( $input{multiple} ), 'alpha', 'Form shows Affected Hosts alpha' );
    for my $name ( sort values %input ) {
        like( $form->value("$name-Original"), qr/^[0-9a-f]{32}$/, "$name-Original holds a digest of the rendered values" );
    }

    $set_values->(
        'Customer Priority' => ['P1'],
        'Severity'          => ['high'],
        'Affected Hosts'    => [ 'beta', 'gamma' ],
    );
    $agent->submit_form_ok( { form_name => 'TicketModifyAll' }, 'Submit the form without touching custom fields' );
    $values_are->(
        { 'Customer Priority' => ['P1'], 'Severity' => ['high'], 'Affected Hosts' => [ 'beta', 'gamma' ] },
        'Untouched fields keep the values set while the form was open'
    );

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    $set_values->( 'Customer Priority' => ['P2'], 'Severity' => ['medium'], 'Affected Hosts' => [] );
    $agent->submit_form_ok(
        {   form_name => 'TicketModifyAll',
            fields    => { $input{single} => 'P4' },
        },
        'Submit the form changing only Customer Priority'
    );
    $values_are->(
        { 'Customer Priority' => ['P4'], 'Severity' => ['medium'], 'Affected Hosts' => [] },
        'The edited field is saved and untouched fields keep the newer values'
    );
    $agent->text_contains( 'Customer Priority P2 changed to P4', 'Customer Priority change reported' );

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    $form = $agent->form_name('TicketModifyAll');
    is( $form->value( $input{multiple} ), '', 'Form shows no Affected Hosts' );
    $set_values->( 'Customer Priority' => ['P4'], 'Severity' => ['medium'], 'Affected Hosts' => ['delta'] );
    $agent->submit_form_ok( { form_name => 'TicketModifyAll' }, 'Submit the form with Affected Hosts left empty' );
    $values_are->(
        { 'Customer Priority' => ['P4'], 'Severity' => ['medium'], 'Affected Hosts' => ['delta'] },
        'A field left empty keeps a value added while the form was open'
    );

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    $agent->submit_form_ok(
        {   form_name => 'TicketModifyAll',
            fields    => { $input{select} => 'high', $input{multiple} => "delta\nepsilon" },
        },
        'Submit the form when nobody else changed the ticket'
    );
    $values_are->(
        { 'Customer Priority' => ['P4'], 'Severity' => ['high'], 'Affected Hosts' => [ 'delta', 'epsilon' ] },
        'Edits are saved as usual without a concurrent change'
    );

    my $text = RT::Test->load_or_create_custom_field(
        Name  => 'Details',
        Queue => 'General',
        Type  => 'TextSingle',
    );
    my $text_input = "Object-RT::Ticket-$ticket_id-CustomField-" . $text->Id . "-Values";
    my $long       = 'A long description. ' x 20;
    $long =~ s/\s+$//;
    my $text_is = sub {
        my ( $expected, $description ) = @_;
        my $current = RT::Ticket->new( RT->SystemUser );
        $current->Load($ticket_id);
        is( $current->FirstCustomFieldValue( $text->Id ), $expected, $description );
    };

    my ( $ok, $msg ) = $ticket->AddCustomFieldValue( Field => $text->Id, Value => $long );
    ok( $ok, 'Set Details to a value stored as large content' ) or diag $msg;

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    is( $agent->form_name('TicketModifyAll')->value($text_input), $long, 'Form shows Details' );
    ( $ok, $msg ) = $ticket->AddCustomFieldValue( Field => $text->Id, Value => "$long Updated." );
    ok( $ok, 'Changed Details while the form was open' ) or diag $msg;
    $agent->submit_form_ok( { form_name => 'TicketModifyAll' }, 'Submit the form without touching Details' );
    $text_is->( "$long Updated.", 'Untouched large content keeps the newer value' );

    $agent->get_ok("/Ticket/ModifyAll.html?id=$ticket_id");
    $agent->submit_form_ok(
        {   form_name => 'TicketModifyAll',
            fields    => { $text_input => '' },
        },
        'Submit the form clearing Details'
    );
    $text_is->( undef, 'Large content can still be cleared' );
}

done_testing;
