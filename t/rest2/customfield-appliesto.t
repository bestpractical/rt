use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

# Create test queues
my $queue1 = RT::Queue->new( RT->SystemUser );
my ( $ok, $msg ) = $queue1->Create( Name => 'CF AppliesTo Queue 1' );
ok( $ok, "Created queue 1: $msg" );

my $queue2 = RT::Queue->new( RT->SystemUser );
( $ok, $msg ) = $queue2->Create( Name => 'CF AppliesTo Queue 2' );
ok( $ok, "Created queue 2: $msg" );

# Create a ticket custom field
my $cf = RT::CustomField->new( RT->SystemUser );
( $ok, $msg ) = $cf->Create(
    Name       => 'Test AppliesTo CF',
    Type       => 'FreeformSingle',
    LookupType => RT::Ticket->CustomFieldLookupType,
);
ok( $ok, "Created custom field: $msg" );

my $cf_id = $cf->Id;
my $appliesto_url = "$rest_base_path/customfield/$cf_id/appliesto";

# -- Permission checks --

diag "GET appliesto requires SeeCustomField";
{
    my $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    is( $res->code, 403, 'Forbidden without SeeCustomField' );

    $user->PrincipalObj->GrantRight(
        Right  => 'SeeCustomField',
        Object => $cf,
    );

    $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    is( $res->code, 200, 'Allowed with SeeCustomField' );

    my $content = $mech->json_response;
    is( $content->{total}, 0, 'No applications yet' );
    is( scalar @{ $content->{items} }, 0, 'Empty items list' );
}

# -- POST to apply CF to a queue --

diag "POST requires AssignCustomFields on target";
{
    my $payload = { ObjectId => $queue1->Id };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 403, 'Forbidden without AssignCustomFields' );
}

# Grant AssignCustomFields and SeeQueue on both queues
for my $queue ($queue1, $queue2) {
    $user->PrincipalObj->GrantRight(
        Right  => 'AssignCustomFields',
        Object => $queue,
    );
    $user->PrincipalObj->GrantRight(
        Right  => 'SeeQueue',
        Object => $queue,
    );
}

diag "POST to apply CF to queue 1";
{
    my $payload = { ObjectId => $queue1->Id };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Applied CF to queue 1' );

    my $content = $mech->json_response;
    is( $content->{ObjectId},   $queue1->Id,              'Response ObjectId' );
    is( $content->{ObjectName}, 'CF AppliesTo Queue 1',   'Response ObjectName' );
    is( $content->{ObjectType}, 'RT::Queue',              'Response ObjectType' );
    like( $content->{_url}, qr{/queue/\d+$},              'Response has object URL' );
}

diag "POST duplicate returns 409";
{
    my $payload = { ObjectId => $queue1->Id };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 409, 'Duplicate application returns 409' );
}

diag "POST to apply CF to queue 2";
{
    my $payload = { ObjectId => $queue2->Id };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Applied CF to queue 2' );
}

diag "GET lists both applications";
{
    my $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    is( $res->code, 200, 'GET appliesto' );

    my $content = $mech->json_response;
    is( $content->{total}, 2, 'Two applications' );
    is( scalar @{ $content->{items} }, 2, 'Two items' );

    my @names = sort map { $_->{ObjectName} } @{ $content->{items} };
    is_deeply( \@names,
        [ 'CF AppliesTo Queue 1', 'CF AppliesTo Queue 2' ],
        'Both queues listed' );
}

# -- POST error cases --

diag "POST without ObjectId returns 400";
{
    my $res = $mech->post_json( $appliesto_url, {}, 'Authorization' => $auth );
    is( $res->code, 400, 'Missing ObjectId returns 400' );
}

diag "POST with nonexistent object returns 400";
{
    my $payload = { ObjectId => 999999 };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 400, 'Nonexistent object returns 400' );
}

diag "POST with invalid ObjectId returns 400";
{
    my $payload = { ObjectId => 'abc' };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 400, 'Non-numeric ObjectId returns 400' );
}

# -- DELETE to remove application --

diag "DELETE removes CF from queue 1";
{
    my $delete_url = "$appliesto_url/object/" . $queue1->Id;
    my $res = $mech->delete( $delete_url, 'Authorization' => $auth );
    is( $res->code, 204, 'Removed CF from queue 1' );

    # Verify removal
    $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    is( $content->{total}, 1, 'One application remaining' );
    is( $content->{items}[0]{ObjectName}, 'CF AppliesTo Queue 2',
        'Only queue 2 remains' );
}

diag "DELETE nonexistent application returns 404";
{
    my $delete_url = "$appliesto_url/object/" . $queue1->Id;
    my $res = $mech->delete( $delete_url, 'Authorization' => $auth );
    is( $res->code, 404, 'Already-removed application returns 404' );
}

# -- Global application --

diag "POST to apply globally";
{
    # Need AssignCustomFields globally for ObjectId=0
    $user->PrincipalObj->GrantRight(
        Right  => 'AssignCustomFields',
        Object => RT->System,
    );

    my $payload = { ObjectId => 0 };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Applied CF globally' );

    my $content = $mech->json_response;
    is( $content->{ObjectId}, 0,            'Response ObjectId is 0' );
    is( $content->{Global},   JSON::true(), 'Response Global is true' );
}

diag "GET shows global application (specific entries removed by AddAndSort)";
{
    my $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    my $content = $mech->json_response;

    # AddAndSort removes specific entries when adding globally
    is( $content->{total}, 1, 'Only global entry remains' );
    is( $content->{items}[0]{Global}, JSON::true(), 'Global flag set' );
    is( $content->{items}[0]{ObjectId}, 0, 'ObjectId is 0' );
}

diag "POST duplicate global returns 409";
{
    my $payload = { ObjectId => 0 };
    my $res = $mech->post_json( $appliesto_url, $payload, 'Authorization' => $auth );
    is( $res->code, 409, 'Duplicate global returns 409' );
}

diag "DELETE global application";
{
    my $delete_url = "$appliesto_url/object/0";
    my $res = $mech->delete( $delete_url, 'Authorization' => $auth );
    is( $res->code, 204, 'Removed global application' );

    $res = $mech->get( $appliesto_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    is( $content->{total}, 0, 'No applications after removing global' );
}

# -- Nonexistent CF --

diag "Nonexistent CF returns 404";
{
    my $bad_url = "$rest_base_path/customfield/999999/appliesto";
    my $res = $mech->get( $bad_url, 'Authorization' => $auth );
    is( $res->code, 404, 'Nonexistent CF returns 404' );
}

# -- Hypermedia link --

diag "CustomField response includes appliesto link";
{
    $user->PrincipalObj->GrantRight(
        Right  => 'AdminCustomField',
        Object => $cf,
    );

    my $res = $mech->get(
        "$rest_base_path/customfield/$cf_id",
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'GET customfield' );

    my $content = $mech->json_response;
    my @links = grep { $_->{ref} eq 'appliesto' } @{ $content->{_hyperlinks} };
    is( scalar @links, 1, 'Has appliesto hyperlink' );
    like( $links[0]{_url}, qr{/customfield/$cf_id/appliesto$},
        'Correct appliesto URL' );
}

done_testing;
