use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;
my ( $baseurl, $m ) = RT::Test->started_ok;
diag "Started server at $baseurl";

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $admin = RT::Test::REST2->user;
$admin->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my( $id, $msg);

my $cf = RT::CustomField->new( RT->SystemUser );
my $cfid;
($cfid, $msg) = $cf->Create(Name => 'TxnCF', Type => 'FreeformSingle', MaxValues => '0', LookupType => RT::Transaction->CustomFieldLookupType );
ok($cfid,$msg);

($id,$msg) = $cf->AddToObject($queue);
ok($id,$msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ( $ticket1_id, $transid );
($ticket1_id, $transid, $msg) = $ticket->Create(Queue => $queue->id, Subject => 'TxnCF test',);
ok( $ticket1_id, $msg );

my $res = $mech->get("$rest_base_path/ticket/$ticket1_id", 'Authorization' => $auth);
is( $res->code, 200, 'Fetched ticket via REST2 API');

{
    my $payload = { Content         => "reply one",
                    ContentType     => "text/plain",
                    TxnCustomFields => { "TxnCF" => "txncf value one"},
                  };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket1_id/correspond", $payload, 'Authorization' => $auth);
    is( $res->code, 201, 'correspond response code is 201');
    is_deeply( $mech->json_response, [ "Correspondence added", "Custom fields updated" ], 'message is "Correspondence Added"');

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ( $ret, $msg ) = $ticket->Load( $ticket1_id );
    ok( $ret, $msg );
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    my $txn = $txns->Last;
    ok( $txn->Id, "Found Correspond transaction" );
    is( $txn->FirstCustomFieldValue('TxnCF'), "txncf value one", 'Found transaction custom field');
}

{
    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };
    my $payload = { Content         => "reply two",
                    ContentType     => "text/plain",
                    TxnCustomFields => { "not a real CF name" => "txncf value"},
                  };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket1_id/correspond", $payload, 'Authorization' => $auth);

    is( scalar @warnings, 1, 'Got one warning' );
    like(
        $warnings[0],
        qr/Unable to load transaction custom field: not a real CF name/,
        'Got the unable to load warning'
    );

    is( $res->code, 201, 'Correspond response code is 201 because correspond succeeded');
    is_deeply( $mech->json_response, [ "Correspondence added", "Unable to load transaction custom field: not a real CF name" ], 'Bogus cf name');
}


# Test as a user.
my $user = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
$user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );
$user->PrincipalObj->GrantRight( Right => 'ReplyToTicket' );
$user->PrincipalObj->GrantRight( Right => 'SeeQueue' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicketComments' );
$user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );
$user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );

my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket for CF test',
        Queue   => 'General',
        Content => 'Ticket for CF test content',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    # We need the hypermedia URLs...
    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $payload = {
        Subject => 'Add Txn with CF',
        Content => 'Content',
        ContentType => 'text/plain',
        'TxnCustomFields' => {
            'TxnCF' => 'Txn CustomField',
         },
    };

    $res = $mech->post_json($mech->url_for_hypermedia('correspond'),
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    my $response = $mech->json_response;


    my $response_value = bag(
        re(qr/Correspondence added|Message added/), 'Custom fields updated',
    );

    cmp_deeply($mech->json_response, $response_value, 'Response containts correct strings');
}

# Look for the Transaction with our CustomField set.
{
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $res = $mech->get($mech->url_for_hypermedia('history'),
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    # Check the correspond txn (0 = create, 1 = correspond)
    my $txn = @{ $content->{items} }[1];

    $res = $mech->get($txn->{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    like($content->{Data}, qr/^Add Txn with CF/);

    cmp_deeply(
        $content->{CustomFields},
        [   {   'values' => ['Txn CustomField'],
                'type'   => 'customfield',
                'id'     => $cfid,
                '_url'   => ignore(),
                'name'   => 'TxnCF',
            }
        ],
        'Txn is set'
    );
}

done_testing();
