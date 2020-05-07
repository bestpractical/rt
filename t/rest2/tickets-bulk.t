use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth           = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Extension::REST2::Test->user;
my $base_url       = RT::Extension::REST2->base_uri;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my @ticket_ids;

{
    my $res = $mech->post_json(
        "$rest_base_path/tickets/bulk",
        { Queue => "General", Subject => "test" },
        'Authorization' => $auth,
    );
    is( $res->code, 400 );
    is( $mech->json_response->{message}, "JSON object must be a ARRAY", 'hash is not allowed' );

    diag "no CreateTicket right";

    $res = $mech->post_json(
        "$rest_base_path/tickets/bulk",
        [ { Queue => "General", Subject => "test" } ],
        'Authorization' => $auth,
    );
    is( $res->code, 201, "bulk returns 201 for POST even no tickets created" );
    is_deeply(
        $mech->json_response,
        [
            {
                message => "No permission to create tickets in the queue 'General'"
            }
        ],
        'permission denied'
    );

    diag "grant CreateTicket right";
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );

    $res = $mech->post_json(
        "$rest_base_path/tickets/bulk",
        [ { Queue => "General", Subject => "test" } ],
        'Authorization' => $auth,
    );
    is( $res->code, 201, 'status code' );
    my $content = $mech->json_response;
    is( scalar @$content, 1, 'array with 1 item' );
    ok( $content->[ 0 ]{id}, 'found id' );
    push @ticket_ids, $content->[ 0 ]{id};
    is_deeply(
        $content,
        [
            {
                type   => 'ticket',
                id     => $ticket_ids[ -1 ],
                "_url" => "$base_url/ticket/$ticket_ids[-1]",
            }
        ],
        'json response content',
    );

    $res = $mech->post_json(
        "$rest_base_path/tickets/bulk",
        [ { Queue => 'General', Subject => 'foo' }, { Queue => 'General', Subject => 'bar' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 201, 'status code' );
    $content = $mech->json_response;
    is( scalar @$content, 2, 'array with 2 items' );
    push @ticket_ids, $_->{id} for @$content;
    is_deeply(
        $content,
        [
            {
                type   => 'ticket',
                id     => $ticket_ids[ -2 ],
                "_url" => "$base_url/ticket/$ticket_ids[-2]",
            },
            {
                type   => 'ticket',
                id     => $ticket_ids[ -1 ],
                "_url" => "$base_url/ticket/$ticket_ids[-1]",
            },
        ],
        'json response content',
    );

    $res = $mech->post_json(
        "$rest_base_path/tickets/bulk",
        [ { Subject => 'foo' }, { Queue => 'General', Subject => 'baz' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 201, 'status code' );
    $content = $mech->json_response;
    is( scalar @$content, 2, 'array with 2 items' );

    push @ticket_ids, $content->[ 1 ]{id};
    is_deeply(
        $content,
        [
            {
                message => "Could not create ticket. Queue not set"
            },
            {
                type   => 'ticket',
                id     => $ticket_ids[ -1 ],
                "_url" => "$base_url/ticket/$ticket_ids[-1]",
            },
        ],
        'json response content',
    );
}

{
    diag "no ModifyTicket right";
    my $res = $mech->put_json(
        "$rest_base_path/tickets/bulk",
        [ { id => $ticket_ids[ 0 ], Subject => 'foo' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200, "bulk returns 200 for PUT" );
    is_deeply( $mech->json_response, [ [ $ticket_ids[ 0 ], "Ticket 1: Permission Denied", ] ], 'permission denied' );

    diag "grant ModifyTicket right";
    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put_json(
        "$rest_base_path/tickets/bulk",
        [ { id => $ticket_ids[ 0 ], Subject => 'foo' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'status code' );
    is_deeply(
        $mech->json_response,
        [ [ $ticket_ids[ 0 ], qq{Ticket 1: Subject changed from 'test' to 'foo'} ] ],
        'json response content'
    );

    $res = $mech->put_json(
        "$rest_base_path/tickets/bulk",
        [ { id => $ticket_ids[ 0 ] }, { id => $ticket_ids[ 1 ], Subject => 'bar' }, ],
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'status code' );
    is_deeply(
        $mech->json_response,
        [
            [ $ticket_ids[ 0 ] ], [ $ticket_ids[ 1 ], qq{Ticket $ticket_ids[ 1 ]: Subject changed from 'foo' to 'bar'} ]
        ],
        'json response content'
    );

    $res = $mech->put_json(
        "$rest_base_path/tickets/bulk",
        [
            { id => $ticket_ids[ 0 ], Subject => 'baz' },
            { id => 'foo',            Subject => 'baz' },
            { id => 999,              Subject => 'baz' },
        ],
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'status code' );
    is_deeply(
        $mech->json_response,
        [
            [ $ticket_ids[ 0 ], qq{Ticket $ticket_ids[ 0 ]: Subject changed from 'foo' to 'baz'} ],
            [ 'foo',            "Resource does not exist" ],
            [ 999,              "Resource does not exist" ],
        ],
        'json response content'
    );
}

{
    for my $method ( qw/get head delete/ ) {
        my $res = $mech->get( "$rest_base_path/tickets/bulk", 'Authorization' => $auth );
        is( $res->code, 405, "tickets/bulk doesn't support " . uc $method );
    }
}

done_testing;

