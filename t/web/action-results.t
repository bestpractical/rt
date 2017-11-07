use strict;
use warnings;
use RT::Test tests => 'no_declare';

my ($url, $m) = RT::Test->started_ok;

ok $m->login, "Logged in";

# We test two ticket creation paths since one historically doesn't update the
# session (quick create) and the other does.
for my $quick (1, 0) {
    diag $quick ? "Quick ticket creation" : "Normal ticket creation";

    $m->get_ok("/");
    $m->submit_form_ok({ form_name => 'CreateTicketInQueue' }, "Create new ticket form")
        unless $quick;
    $m->submit_form_ok({
        with_fields => {
            Subject => "The Plants",
            Content => "Please water them.",
        },
    }, "Submitted new ticket");

    my $id = RT::Test->last_ticket->id;

    like $m->uri, qr/results=[A-Za-z0-9]{32}/, "URI contains results hash";
    $m->content_contains("Ticket $id created", "Page contains results message");
    $m->content_contains("#$id: The Plants") unless $quick;

    diag "Reloading without a referer but with a results hash doesn't trigger the CSRF"; {
        # Mech's API here sucks.  To drop the Referer and simulate a real browser
        # reload, we need to make a new request which explicitly adds an empty Referer
        # header (causing it to never be sent) and then deletes the empty Referer
        # header to let it be automatically managed again.
        $m->add_header("Referer" => undef);
        $m->get_ok( $m->uri, "Reloading the results page without a Referer" );
        $m->delete_header("Referer");

        like $m->uri, qr/results=[A-Za-z0-9]{32}/, "URI contains results hash";
        $m->content_lacks("cross-site request forgery", "Skipped the CSRF interstitial")
            or $m->follow_link_ok({ text => "click here to resume your request" }, "Ignoring CSRF warning");
        $m->content_lacks("Ticket $id created", "Page lacks results message");
        $m->content_contains("#$id: The Plants") unless $quick;
    }
}

done_testing;
