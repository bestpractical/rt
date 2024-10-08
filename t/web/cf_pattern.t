use strict;
use warnings;

use RT::Test tests => 'no_declare';

my ($base, $m) = RT::Test->started_ok;

my $cf_yaks = RT::Test->load_or_create_custom_field(
    Name        => 'Yaks',
    Type        => 'FreeformSingle',
    Pattern     => '(?#Digits)^\d+$',
    Queue       => 0,
    LookupType  => 'RT::Queue-RT::Ticket',
);
ok $cf_yaks && $cf_yaks->id, "Created CF with Pattern";

my $cf_guars = RT::Test->load_or_create_custom_field(
    Name        => 'Guars',
    Type        => 'FreeformSingle',
    Pattern     => '^\d+$',
    Queue       => 0,
    LookupType  => 'RT::Queue-RT::Ticket',
);
ok $cf_guars && $cf_guars->id, "Created CF with commentless Pattern";

my $cf_bison = RT::Test->load_or_create_custom_field(
    Name           => 'Bison',
    Type           => 'FreeformSingle',
    Pattern        => '(?#Digits)^\d+$',
    Queue          => 0,
    LookupType     => 'RT::Queue-RT::Ticket',
    ValidationHint => 'Buffalo',
);
ok $cf_bison && $cf_bison->id, "Created CF with Pattern and ValidationHint";

my $cf_zebus = RT::Test->load_or_create_custom_field(
    Name           => 'Zebus',
    Type           => 'FreeformSingle',
    Pattern        => '^\d+$',
    Queue          => 0,
    LookupType     => 'RT::Queue-RT::Ticket',
    ValidationHint => 'AKA Cebu',
);
ok $cf_zebus && $cf_zebus->id, "Created CF with commentless Pattern and ValidationHint";

my $cf_gnus = RT::Test->load_or_create_custom_field(
    Name           => 'Gnus',
    Type           => 'FreeformSingle',
    Queue          => 0,
    LookupType     => 'RT::Queue-RT::Ticket',
    ValidationHint => 'No Gnus',
);
ok $cf_gnus && $cf_gnus->id, "Created CF with ValidationHint without Pattern";

my $ticket = RT::Test->create_ticket(
    Queue   => 1,
    Subject => 'a test ticket',
);
ok $ticket && $ticket->id, "Created ticket";

$m->login;

for my $page ("/Ticket/Create.html?Queue=1", "/Ticket/ModifyAll.html?id=".$ticket->id) {
    diag $page;
    $m->get_ok($page, "Fetched $page");
    $m->content_contains("Yaks");
    $m->content_contains("Input must match [Digits]");
    $m->content_contains("Guars");
    $m->content_contains("Input must match ^\\d+\$");
    $m->content_contains("Bison");
    $m->content_contains("Buffalo");
    $m->content_contains("Zebus");
    $m->content_contains("AKA Cebu");
    $m->content_contains("Gnus");
    $m->content_lacks("No Gnus");
    $m->content_lacks("cfinvalidfield");

    my $cfinput_yaks = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf_yaks,
    );
    my $cfinput_guars = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf_guars,
    );
    my $cfinput_bison = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf_bison,
    );
    my $cfinput_zebus = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf_zebus,
    );
    my $cfinput_gnus = RT::Interface::Web::GetCustomFieldInputName(
        Object => ( $page =~ /Create/ ? RT::Ticket->new( RT->SystemUser ) : $ticket ),
        CustomField => $cf_gnus,
    );
    $m->submit_form_ok({
        with_fields => {
            $cfinput_yaks            => "too many",
            "${cfinput_yaks}-Magic"  => "1",
            $cfinput_guars           => "too many",
            "${cfinput_guars}-Magic" => "1",
            $cfinput_bison           => "too many",
            "${cfinput_bison}-Magic" => "1",
            $cfinput_zebus           => "too many",
            "${cfinput_zebus}-Magic" => "1",
            $cfinput_gnus            => "too many",
            "${cfinput_gnus}-Magic"  => "1",
        },
    });
    $m->content_contains("Input must match [Digits]");
    $m->content_contains("Input must match ^\\d+\$");
    $m->content_contains("Buffalo");
    $m->content_contains("AKA Cebu");
    $m->content_lacks("No Gnus");
    $m->content_contains("cfinvalidfield");

    $m->submit_form_ok({
        with_fields => {
            $cfinput_yaks            => "42",
            "${cfinput_yaks}-Magic"  => "1",
            $cfinput_guars           => "42",
            "${cfinput_guars}-Magic" => "1",
            $cfinput_bison           => "42",
            "${cfinput_bison}-Magic" => "1",
            $cfinput_zebus           => "42",
            "${cfinput_zebus}-Magic" => "1",
            $cfinput_gnus            => "too many",
            "${cfinput_gnus}-Magic"  => "1",
        },
        button => 'SubmitTicket',
    });

    if ($page =~ /Create/) {
        $m->content_like(qr/Ticket \d+ created/, "Created ticket");
    } else {
        $m->content_contains("Yaks 42 added", "Updated ticket Yaks");
        $m->content_contains("Guars 42 added", "Updated ticket Guars");
        $m->content_contains("Bison 42 added", "Updated ticket Bison");
        $m->content_contains("Zebus 42 added", "Updated ticket Zebu");
        $m->content_contains("Gnus too many added", "Updated ticket Gnus");
        $m->content_contains("Input must match [Digits]");
        $m->content_contains("Input must match ^\\d+\$");
        $m->content_contains("Buffalo");
        $m->content_contains("AKA Cebu");
        $m->content_lacks("No Gnus");
        $m->content_lacks("cfinvalidfield");
    }
}

done_testing;
