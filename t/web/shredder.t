use strict;
use warnings;

use RT::Test;

RT::Config->Set('ShredderStoragePath', RT::Test->temp_directory . '');

my ( $baseurl, $agent ) = RT::Test->started_ok;

diag("Test server running at $baseurl");

$agent->login('root' => 'password');

my $ticket_id;
# Ticket created in block to avoid scope error on destroy
{
    my $ticket = RT::Test->create_ticket( Subject => 'test shredder', Queue => 1, );
    ok( $ticket->Id, "created new ticket" );

    $ticket_id = $ticket->id;
}

{
    $agent->get_ok($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Tickets'},
    }, "Select Tickets shredder plugin");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'Tickets:query'  => 'id=' . $ticket_id,
        },
        button => 'Search',
    }, "Search for ticket object");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::Ticket-example.com-' . $ticket_id,
        },
        button => 'Wipeout',
    }, "Select and destroy ticket object");
    $agent->text_contains('objects were successfuly removed', 'Found success message' );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($ret, $msg) = $ticket->Load($ticket_id);

    ok !$ret, 'Ticket successfully shredded';
}

# Shred RT::User
{
    my $user = RT::Test->load_or_create_user( EmailAddress => 'test@example.com' );

    my $id = $user->id;
    ok $id;

    $agent->get_ok($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Users'},
    }, "Select Users shredder plugin");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'Users:email'  => 'test@example.com',
            'Users:status' => 'Enabled',
        },
        button => 'Search',
    }, "Search for user");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::User-test@example.com',
        },
        button => 'Wipeout',
    }, "Select and destroy searched user");
    $agent->text_contains('objects were successfuly removed', 'Found success message' );

    my ($ret, $msg) = $user->Load($id);
    ok !$ret, 'User successfully shredded';
}

done_testing();
