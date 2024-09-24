use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech           = RT::Test::REST2->mech;
my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => $_ ) for qw/SeeOwnSavedSearch AdminOwnSavedSearch/;

my $custom_role = RT::CustomRole->new( RT->SystemUser );
my ( $ret, $msg ) = $custom_role->Create(
    Name      => 'Manager',
    MaxValues => 0,
);
ok( $ret, "created custom role: $msg" );

( $ret, $msg ) = $custom_role->AddToObject(1);
ok( $ret, "added custom role to queue: $msg" );
my $custom_role_type = $custom_role->GroupType;

my $cf = RT::CustomField->new( RT->SystemUser );
( $ret, $msg ) = $cf->Create( Name => 'Boss', Type => 'Freeform', LookupType => RT::User->CustomFieldLookupType );
ok( $ret, "created custom field: $msg" );
ok( $cf->AddToObject( RT::User->new( RT->SystemUser ) ) );

ok( $user->SetCountry('US') );
ok( $user->AddCustomFieldValue( Field => $cf, Value => 'root' ) );

my $search1 = RT::SavedSearch->new($user);
( $ret, $msg ) = $search1->Create(
    PrincipalId => $user->Id,
    Type        => 'Ticket',
    Name        => 'My own tickets',
    Content     => {
        RowsPerPage => 50,
        'Format'    => join( ',',
            RT->Config->Get('DefaultSearchResultFormat'), '__Requestors.Country__',
            '__CustomRole.{Manager}.CustomField.{Boss}__' ),
        'Query' => "Owner = '" . $user->Name . "'",
    },
);

ok( $ret, "created $msg" );

my $search2 = RT::SavedSearch->new( RT->SystemUser );
( $ret, $msg ) = $search2->Create(
    PrincipalId => RT->System->Id,
    Type        => 'Ticket',
    Name        => 'Recently created tickets',
    Content     => {
        'Format' => RT->Config->Get('DefaultSearchResultFormat'),
        'Query'  => "Created >= 'yesterday'",
    },
);

ok( $ret, "created $msg" );

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

{
    my $res = $mech->get( "$rest_base_path/searches", 'Authorization' => $auth, );
    is( $res->code, 200, 'got /searches' );

    my $content = $mech->json_response;
    is( $content->{count},             5,  '5 searches' );
    is( $content->{page},              1,  '1 page' );
    is( $content->{per_page},          20, '20 per_page' );
    is( $content->{total},             5,  '5 total' );
    is( scalar @{ $content->{items} }, 5,  'items count' );

    for my $item ( @{ $content->{items} } ) {
        ok( $item->{id}, 'search id' );
        is( $item->{type}, 'search', 'search type' );
        like( $item->{_url}, qr{$rest_base_path/search/$item->{id}}, 'search url' );
    }

    is( $content->{items}[3]{id}, $search1->Id, 'search id' );
    is( $content->{items}[4]{id}, $search2->Id, 'search id' );
}

{
    my $res = $mech->post_json(
        "$rest_base_path/searches",
        [ { field => 'Description', value => 'My own tickets' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200, "got $rest_base_path/searches" );

    my $content = $mech->json_response;
    is( $content->{count},             1,  '1 search' );
    is( $content->{page},              1,  '1 page' );
    is( $content->{per_page},          20, '20 per_page' );
    is( $content->{total},             1,  '1 total' );
    is( scalar @{ $content->{items} }, 1,  'items count' );

    is( $content->{items}[0]{id}, $search1->Id, 'search id' );
}

# Single search
{
    my $res = $mech->get( "$rest_base_path/search/" . $search1->Id, 'Authorization' => $auth, );
    is( $res->code, 200, "got $rest_base_path/search/" . $search1->Id );

    my $content = $mech->json_response;
    is( $content->{id},          $search1->id,  'id' );
    is( $content->{Name},        'My own tickets', 'Name' );
    is( $content->{Description}, 'My own tickets',  'Description' );

    my $links = $content->{_hyperlinks};
    is( scalar @$links, 2, 'links count' );

    is( $links->[0]{ref},  'self',       'self link ref' );
    is( $links->[0]{id},   $search1->Id, 'self link id' );
    is( $links->[0]{type}, 'search',     'self link type' );
    like( $links->[0]{_url}, qr[$rest_base_path/search/$links->[0]{id}$], 'self link url' );

    is( $links->[1]{ref},  'tickets', 'results link ref' );
    is( $links->[1]{type}, 'results', 'results link type' );
    like( $links->[1]{_url}, qr[$rest_base_path/tickets\?search=$content->{id}$], 'results link url' );

    $res = $mech->get( "$rest_base_path/search/My own tickets", 'Authorization' => $auth, );
    is( $res->code, 200, "got $rest_base_path/search/" . $search1->Id );
    is_deeply( $content, $mech->json_response, 'Access via search name' );
}

{
    my $ticket1 = RT::Test->create_ticket(
        Queue             => 1,
        Subject           => 'test ticket',
        Owner             => $user->Id,
        Requestor         => $user->Id,
        $custom_role_type => $user->Id
    );
    my $ticket2 = RT::Test->create_ticket( Queue => 1, Subject => 'test ticket' );
    my $res     = $mech->get( "$rest_base_path/tickets?search=" . $search1->Id, 'Authorization' => $auth, );
    is( $res->code, 200, "got $rest_base_path/tickets?search=" . $search1->Id );

    my $content = $mech->json_response;
    is( $content->{count},             1,  '1 search' );
    is( $content->{page},              1,  '1 page' );
    is( $content->{per_page},          50, '50 per_page' );
    is( $content->{total},             1,  '1 total' );
    is( scalar @{ $content->{items} }, 1,  'items count' );

    my $item = $content->{items}[0];
    is( $item->{id}, $ticket1->Id, 'ticket id' );
    for my $field ( qw/Requestor Owner Status TimeLeft Subject Priority Created LastUpdated Told Queue/,
        $custom_role_type )
    {
        ok( length $item->{$field}, "$field value not empty" );
    }
    is( $item->{Subject},               'test ticket', 'Subject value' );
    is( $item->{Queue}{Name},           'General',     'Queue name' );
    is( $item->{Requestor}[0]{id},      $user->Name,   'Requestor id' );
    is( $item->{Requestor}[0]{Country}, 'US',          'Requestor Country' );

    is( $item->{$custom_role_type}[0]{id},                         $user->Name, 'Manager id' );
    is( $item->{$custom_role_type}[0]{CustomFields}[0]{name},      'Boss',      'Manager Boss' );
    is( $item->{$custom_role_type}[0]{CustomFields}[0]{values}[0], 'root',      'Manager Boss name' );

    $res = $mech->get( "$rest_base_path/tickets?search=My own tickets", 'Authorization' => $auth, );
    is( $res->code, 200, "got $rest_base_path/tickets?search=My own tickets" );
    is_deeply( $content, $mech->json_response, 'search tickets via search name' );

    $res = $mech->get( "$rest_base_path/tickets?search=My own tickets&per_page=10&fields=id", 'Authorization' => $auth, );
    is( $res->code, 200, "got $rest_base_path/tickets?search=My own tickets" );
    $content = $mech->json_response;
    is( $content->{count},             1,  '1 search' );
    is( $content->{page},              1,  '1 page' );
    is( $content->{per_page},          10, '10 per_page' );
    is( $content->{total},             1,  '1 total' );
    is( scalar @{ $content->{items} }, 1,  'items count' );

    $item = $content->{items}[0];
    is( $item->{id}, $ticket1->Id, 'ticket id' );
    for my $field ( qw/Requestor Owner Status TimeLeft Subject Priority Created LastUpdated Told Queue/,
        $custom_role_type )
    {
        ok( !exists $item->{$field}, "$field not exists" );
    }
}

done_testing;
