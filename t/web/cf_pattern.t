use strict;
use warnings;

use RT::Test tests => 'no_declare';

my ($base, $m) = RT::Test->started_ok;

my $cf = RT::Test->load_or_create_custom_field(
    Name        => 'Yaks',
    Type        => 'FreeformSingle',
    Pattern     => '(?#Digits)^\d+$',
    Queue       => 0,
    LookupType  => 'RT::Queue-RT::Ticket',
);
ok $cf && $cf->id, "Created CF with Pattern";

my $ticket = RT::Test->create_ticket(
    Queue   => 1,
    Subject => 'a test ticket',
);
ok $ticket && $ticket->id, "Created ticket";

$m->login;

for my $page ("/Ticket/Create.html?Queue=1", "/Ticket/Modify.html?id=".$ticket->id) {
    diag $page;
    $m->get_ok($page, "Fetched $page");
    $m->content_contains("Yaks");
    $m->content_contains("Input must match [Digits]");
    $m->content_lacks("cfinvalidfield");

    my $cfinput = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf,
    );
    $m->submit_form_ok({
        with_fields => {
            $cfinput            => "too many",
            "${cfinput}-Magic" => "1",
        },
    });
    $m->content_contains("Input must match [Digits]");
    $m->content_contains("cfinvalidfield");

    $m->submit_form_ok({
        with_fields => {
            $cfinput            => "42",
            "${cfinput}-Magic" => "1",
        },
    });

    if ($page =~ /Create/) {
        $m->content_like(qr/Ticket \d+ created/, "Created ticket");
    } else {
        $m->content_contains("Yaks 42 added", "Updated ticket");
        $m->content_contains("Input must match [Digits]");
        $m->content_lacks("cfinvalidfield");
    }
}

diag "Quick ticket creation";
{
    $m->get_ok("/");
    $m->submit_form_ok({
        with_fields => {
            Subject     => "test quick create",
            QuickCreate => 1,
        },
    });
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->FromSQL("Subject = 'test quick create'");
    is $tickets->Count, 0, "No ticket created";

    like $m->uri, qr/Ticket\/Create\.html/, "Redirected to the ticket create page";
    $m->content_contains("Yaks: Input must match", "Found CF validation error");
    $m->content_contains("test quick create", "Found prefilled Subject");
}

done_testing;
