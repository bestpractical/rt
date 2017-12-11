use strict;
use warnings;

use RT::Test tests => undef;

my @groupings = qw/Basics Dates People Links More/;
RT->Config->Set( 'CustomFieldGroupings',
    'RT::Ticket' => {
        map { +($_ => ["Test$_"]) } @groupings,
    },
);

my %CF;
for my $grouping (@groupings) {
    my $name = "Test$grouping";
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $cf->Create(
        Name => $name,
        Queue => '0',
        Description => 'A Testing custom field',
        Type => 'FreeformSingle',
        Pattern => '^(?!bad value).*$',
    );
    ok $id, "custom field '$name' correctly created";
    $CF{$grouping} = $id;
}

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my %location = (
    Basics => ".ticket-info-basics",
    Dates  => ".ticket-info-dates",
    People => "#ticket-create-message",
    Links  => ".ticket-info-links",
    More   => ".ticket-info-cfs",
);
{
    note "testing Create";
    $m->goto_create_ticket($queue);

    my $prefix = 'Object-RT::Ticket--CustomField:';
    my $dom = $m->dom;
    $m->form_name('TicketCreate');
    $m->field("Subject", "CF grouping test");

    for my $grouping (@groupings) {
        my $input_name = $prefix . "$grouping-$CF{$grouping}-Value";
        is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
        ok $dom->at(qq{$location{$grouping} input[name="$input_name"]}), "CF is in the right place";
        $m->field( $input_name, "Test" . $grouping . "Value" );
    }
    $m->submit;
}

my $id = $m->get_ticket_id;
{
    note "testing Display";
    ok $id, "created a ticket";
    my $dom = $m->dom;

    $location{People} = ".ticket-info-people";
    foreach my $grouping (@groupings) {
        my $row_id = "CF-$CF{$grouping}-ShowRow";
        is $dom->find(qq{#$row_id})->size, 1, "CF on the page";
        like $dom->at(qq{#$row_id})->all_text, qr/Test$grouping:\s*Test${grouping}Value/, "value is set";
        ok $dom->at(qq{$location{$grouping} #$row_id}), "CF is in the right place";
    }
}

{
    note "testing Basics/People/Dates/Links pages";
    my $prefix = 'Object-RT::Ticket-'. $id .'-CustomField:';
    { # Basics and More both show up on "Basics"
        for my $name (qw/Basics More/) {
            $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');
            is $m->dom->find(qq{input[name^="$prefix"][name\$="-Value"]})->size, 2,
                "two CF inputs on the page";

            my $input_name = "$prefix$name-$CF{$name}-Value";
            ok $m->dom->at(qq{$location{$name} input[name="$input_name"]}),
                "CF is in the right place";
            $m->submit_form_ok({
                with_fields => { $input_name => "Test${name}Changed" },
                button      => 'SubmitTicket',
            });
            $m->content_like(qr{to Test${name}Changed});

            $m->submit_form_ok({
                with_fields => { $input_name => "bad value" },
                button      => 'SubmitTicket',
            });
            $m->content_like(qr{Test\Q$name\E: Input must match});
        }
    }

    # Everything else gets its own page
    foreach my $name ( qw(People Dates Links) ) {
        $m->follow_link_ok({id => "page-\L$name"}, "Ticket's $name page");
        is $m->dom->find(qq{input[name^="$prefix"][name\$="-Value"]})->size, 1,
            "only one CF input on the page";
        my $input_name = "$prefix$name-$CF{$name}-Value";
        $m->submit_form_ok({
            with_fields => { $input_name => "Test${name}Changed" },
            button      => 'SubmitTicket',
        });
        $m->content_like(qr{to Test${name}Changed});

        $m->submit_form_ok({
            with_fields => { $input_name => "bad value" },
            button      => 'SubmitTicket',
        });
        $m->content_like(qr{Could not add new custom field value: Input must match});
    }
}

{
    note "testing Jumbo";
    my $prefix = 'Object-RT::Ticket-'. $id .'-CustomField:';
    $m->follow_link_ok({id => "page-jumbo"}, "Ticket's Jumbo page");
    my $dom = $m->dom;
    $m->form_name("TicketModifyAll");

    foreach my $name ( qw(Basics People Dates Links More) ) {
        my $input_name = "$prefix$name-$CF{$name}-Value";
        is $dom->find(qq{input[name="$input_name"]})->size, 1,
            "only one CF input on the page";
        $m->field( $input_name, "Test${name}Again" );
    }
    $m->click('SubmitTicket');
    foreach my $name ( qw(Basics People Dates Links More) ) {
        $m->content_like(qr{to Test${name}Again});
    }
}

{
    note "Reconfigure to place one CF in multiple boxes";
    $m->no_warnings_ok;
    RT::Test->stop_server;

    RT->Config->Set( 'CustomFieldGroupings',
        'RT::Ticket' => {
            Basics => [ 'TestMore' ],
            More   => [ 'TestMore' ],
        },
    );

    ( $baseurl, $m ) = RT::Test->started_ok;
    ok $m->login, 'logged in as root';
}

{
    note "Testing one CF in multiple boxes";
    $m->goto_create_ticket($queue);

    my $prefix = 'Object-RT::Ticket--CustomField:';
    my $dom = $m->dom;
    $m->form_name('TicketCreate');

    my $cf = $CF{More};
    is $m->dom->find(qq{input[name^="$prefix"][name\$="-$cf-Value"]})->size, 2,
        "Two 'More' CF inputs on the page";
    for my $grouping (qw/Basics More/) {
        my $input_name = $prefix . "$grouping-$cf-Value";
        is $dom->find(qq{input[name="$input_name"]})->size, 1, "Found the $grouping grouping";
        ok $dom->at(qq{$location{$grouping} input[name="$input_name"]}), "CF is in the right place";
        $m->field( $input_name, "TestMoreValue" );
    }
    $m->submit;
    $m->no_warnings_ok( "Submitting CF with two (identical) values had no warnings" );
}

$id = $m->get_ticket_id;
my $ticket = RT::Ticket->new ( RT->SystemUser );
$ticket->Load( $id );
is $ticket->CustomFieldValuesAsString( "TestMore", Separator => "|" ), "TestMoreValue",
    "Value submitted twice is set correctly (and only once)";

my $cf = $CF{More};
my $prefix = 'Object-RT::Ticket-'. $id .'-CustomField:';
{
    note "Updating with multiple appearances of a CF";
    $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');

    is $m->dom->find(qq{input[name^="$prefix"][name\$="-$cf-Value"]})->size, 2,
        "Two 'More' CF inputs on the page";
    my @inputs;
    for my $grouping (qw/Basics More/) {
        my $input_name =  "$prefix$grouping-$cf-Value";
        push @inputs, $input_name;
        ok $m->dom->at(qq{$location{$grouping} input[name="$input_name"]}),
            "CF is in the right place";
    }
    $m->submit_form_ok({
        with_fields => {
            map {+($_ => "TestMoreChanged")} @inputs,
        },
        button => 'SubmitTicket',
    });
    $m->no_warnings_ok;
    $m->content_like(qr{to TestMoreChanged});

    $ticket->Load( $id );
    is $ticket->CustomFieldValuesAsString( "TestMore", Separator => "|" ), "TestMoreChanged",
        "Updated value submitted twice is set correctly (and only once)";
}

{
    note "Updating with _differing_ values in multiple appearances of a CF";

    my %inputs = map {+($_ => "$prefix$_-$cf-Value")} qw/Basics More/;
    $m->submit_form_ok({
        with_fields => {
            $inputs{Basics} => "BasicsValue",
            $inputs{More}   => "MoreValue",
        },
        button => 'SubmitTicket',
    });
    $m->warning_like(qr{CF $cf submitted with multiple differing values});
    $m->content_like(qr{to BasicsValue}, "Arbitrarily chose first value");

    $ticket->Load( $id );
    is $ticket->CustomFieldValuesAsString( "TestMore", Separator => "|" ), "BasicsValue",
        "Conflicting value submitted twice is set correctly (and only once)";
}

{
    note "Configuring CF to be a select-multiple";
    my $custom_field = RT::CustomField->new( RT->SystemUser );
    $custom_field->Load( $cf );
    $custom_field->SetType( "Select" );
    $custom_field->SetMaxValues( 0 );
    $custom_field->AddValue( Name => $_ ) for 1..9;
}

{
    note "Select multiples do not interfere with each other when appearing multiple times";
    $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');

    $m->form_name('TicketModify');
    my %inputs = map {+($_ => "$prefix$_-$cf-Values")} qw/Basics More/;
    ok $m->dom->at(qq{select[name="$inputs{Basics}"]}), "Found 'More' CF in Basics box";
    ok $m->dom->at(qq{select[name="$inputs{More}"]}),   "Found 'More' CF in More box";

    $m->select( $inputs{Basics} => [1, 3, 9] );
    $m->select( $inputs{More}   => [1, 3, 9] );
    $m->click( 'SubmitTicket' );
    $m->no_warnings_ok;
    $m->content_like(qr{$_ added as a value for TestMore}) for 1, 3, 9;
    $m->content_like(qr{BasicsValue is no longer a value for custom field TestMore});

    $ticket->Load( $id );
    is $ticket->CustomFieldValuesAsString( "TestMore", Separator => "|" ), "1|3|9",
        "Multi-select values submitted correctly";
}

{
    note "Submit multiples correctly choose one set of values when conflicting information is submitted";
    $m->form_name('TicketModify');
    my %inputs = map {+($_ => "$prefix$_-$cf-Values")} qw/Basics More/;
    $m->select( $inputs{Basics} => [2, 3, 4] );
    $m->select( $inputs{More}   => [8, 9] );
    $m->click( 'SubmitTicket' );
    $m->warning_like(qr{CF $cf submitted with multiple differing values});
    $m->content_like(qr{$_ added as a value for TestMore}) for 2, 4;
    $m->content_unlike(qr{$_ added as a value for TestMore}) for 8;
    $m->content_like(qr{$_ is no longer a value for custom field TestMore}) for 1, 9;

    $ticket->Load( $id );
    is $ticket->CustomFieldValuesAsString( "TestMore", Separator => "|" ), "3|2|4",
        "Multi-select values submitted correctly";
}

done_testing;
