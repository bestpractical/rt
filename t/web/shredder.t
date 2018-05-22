use strict;
use warnings;

use RT::Test;

RT::Config->Set('ShredderStoragePath', RT::Test->temp_directory . '');

my ( $baseurl, $agent ) = RT::Test->started_ok;

diag("Test server running at $baseurl");

my $ticket_id;
{
    $agent->login('root' => 'password');
    is( $agent->status, 200, "Fetched the page ok");

    my $ticket = RT::Test->create_ticket( Subject => 'test shredder', Queue => 1, );
    ok( $ticket->Id, "created new ticket" );

    $ticket_id = $ticket->id;
}

{
    $agent->get($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Tickets'},
    );

    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => {
            'Tickets:query'  => 'id=' . $ticket_id,
        },
        button => 'Search',
    );

    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::Ticket-example.com-1',
        },
        button => 'Wipeout',
    );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($ret, $msg) = $ticket->Load($ticket_id);

    ok !$ret, 'Ticket successfully shredded';
}

# Shred RT::User
{
    my $user = RT::User->new(RT->SystemUser);
    my ($ret, $msg) = $user->LoadOrCreateByEmail('test@example.com');
    ok $ret;

    my $id = $user->id;
    ok $id;

    $agent->get($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Users'},
    );

    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => {
            'Users:email'  => 'test@example.com',
            'Users:status' => 'Enabled',
        },
        button => 'Search',
    );

    $agent->submit_form(
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::User-test@example.com',
        },
        button => 'Wipeout',
    );

    ($ret, $msg) = $user->Load($id);
    ok !$ret, 'User successfully shredded';
}

done_testing();
