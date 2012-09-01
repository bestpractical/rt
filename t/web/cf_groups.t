use strict;
use warnings;

use RT::Test tests => 67;

RT->Config->Set( 'CustomFieldGroups',
    'RT::Ticket' => {
        Basics => ['TestBasics'],
        Dates  => ['TestDates'],
        People => ['TestPeople'],
        Links  => ['TestLinks'],
        More   => ['TestMore'],
    },
);

my %CF;

foreach my $name ( map { @$_ } values %{ RT->Config->Get('CustomFieldGroups')->{'RT::Ticket'} } ) {
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $cf->Create(
        Name => $name,
        Queue => '0',
        Description => 'A Testing custom field',
        Type => 'FreeformSingle',
        Pattern => qr{^(?!bad value).*$},
    );
    ok $id, "custom field '$name' correctly created";
    $CF{$name} = $cf;
}

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

{
    note "testing Create";
    $m->goto_create_ticket($queue);

    my $prefix = 'Object-RT::Ticket--CustomField-';
    my $dom = $m->dom;
    $m->form_name('TicketCreate');

    my $input_name = $prefix . $CF{'TestBasics'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.ticket-info-basics input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestBasicsValue' );

    $input_name = $prefix . $CF{'TestPeople'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{#ticket-create-message input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestPeopleValue' );

    $input_name = $prefix . $CF{'TestDates'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.ticket-info-dates input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestDatesValue' );

    $input_name = $prefix . $CF{'TestLinks'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.ticket-info-links input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestLinksValue' );

    $input_name = $prefix . $CF{'TestMore'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.ticket-info-cfs input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestMoreValue' );

    $m->submit;

    note "testing Display";
    my $id = $m->get_ticket_id;
    ok $id, "created a ticket";
    $dom = $m->dom;

    foreach my $name ( qw(Basics People Dates Links) ) {
        my $row_id = 'CF-'. $CF{"Test$name"}->id .'-ShowRow';
        is $dom->find(qq{#$row_id})->size, 1, "CF on the page";
        is $dom->at(qq{#$row_id})->all_text, "Test$name: Test${name}Value", "value is set";
        ok $dom->at(qq{.ticket-info-\L$name\E #$row_id}), "CF is in the right place";
    }
    {
        my $row_id = 'CF-'. $CF{"TestMore"}->id .'-ShowRow';
        is $dom->find(qq{#$row_id})->size, 1, "CF on the page";
        is $dom->at(qq{#$row_id})->all_text, "TestMore: TestMoreValue", "value is set";
        ok $dom->at(qq{.ticket-info-cfs #$row_id}), "CF is in the right place";
    }

    $prefix = 'Object-RT::Ticket-'. $id .'-CustomField-';

    note "testing Basics/People/Dates/Links pages";
    { # Basics
        $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');
        $m->form_name("TicketModify");
        is $m->dom->find(qq{input[name^="$prefix"][name\$="-Value"]})->size, 2,
            "only one CF input on the page";
        my $input_name = $prefix . $CF{'TestBasics'}->id .'-Value';
        ok $m->dom->at(qq{.ticket-info-basics input[name="$input_name"]}),
            "CF is in the right place";
        $m->field( $input_name, "TestBasicsChanged" );
        $m->click('SubmitTicket');
        $m->content_like(qr{to TestBasicsChanged});

        $m->form_name("TicketModify");
        $m->field( $input_name, "bad value" );
        $m->click('SubmitTicket');
        $m->content_like(qr{Input must match});
    }
    { # Custom group 'More'
        $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');
        $m->form_name("TicketModify");
        my $input_name = $prefix . $CF{'TestMore'}->id .'-Value';
        ok $m->dom->at(qq{.ticket-info-cfs input[name="$input_name"]}),
            "CF is in the right place";
        $m->field( $input_name, "TestMoreChanged" );
        $m->click('SubmitTicket');
        $m->content_like(qr{to TestMoreChanged});

        $m->form_name("TicketModify");
        $m->field( $input_name, "bad value" );
        $m->click('SubmitTicket');
        $m->content_like(qr{Input must match});
    }

    foreach my $name ( qw(People Dates Links) ) {
        $m->follow_link_ok({id => "page-\L$name"}, "Ticket's $name page");
        $m->form_name("Ticket$name");
        is $m->dom->find(qq{input[name^="$prefix"][name\$="-Value"]})->size, 1,
            "only one CF input on the page";
        my $input_name = $prefix . $CF{"Test$name"}->id .'-Value';
        $m->field( $input_name, "Test${name}Changed" );
        $m->click('SubmitTicket');
        $m->content_like(qr{to Test${name}Changed});

        $m->form_name("Ticket$name");
        $m->field( $input_name, "bad value" );
        $m->click('SubmitTicket');
        $m->content_like(qr{Input must match});
    }

    note "testing Jumbo";
    $m->follow_link_ok({id => "page-jumbo"}, "Ticket's Jumbo page");
    $dom = $m->dom;
    $m->form_name("TicketModifyAll");

    foreach my $name ( qw(Basics People Dates Links More) ) {
        my $input_name = $prefix . $CF{"Test$name"}->id .'-Value';
        is $dom->find(qq{input[name="$input_name"]})->size, 1,
            "only one CF input on the page";
        $m->field( $input_name, "Test${name}Again" );
    }
    $m->click('SubmitTicket');
    foreach my $name ( qw(Basics People Dates Links More) ) {
        $m->content_like(qr{to Test${name}Again});
    }
}
