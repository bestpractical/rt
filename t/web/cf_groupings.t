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
        is $dom->at(qq{#$row_id})->all_text, "Test$grouping: Test${grouping}Value", "value is set";
        ok $dom->at(qq{$location{$grouping} #$row_id}), "CF is in the right place";
    }
}

{
    note "testing Basics/People/Dates/Links pages";
    my $prefix = 'Object-RT::Ticket-'. $id .'-CustomField:';
    { # Basics and More both show up on "Basics"
        $m->follow_link_ok({id => 'page-basics'}, 'Ticket -> Basics');
        is $m->dom->find(qq{input[name^="$prefix"][name\$="-Value"]})->size, 2,
            "two CF inputs on the page";
        for my $name (qw/Basics More/) {
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
            $m->content_like(qr{Input must match});
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
        $m->content_like(qr{Input must match});
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

undef $m;
done_testing;
