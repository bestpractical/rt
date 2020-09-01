use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech           = RT::Test::REST2->mech;
my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $class_url;

# search Name = General
{
    my $res = $mech->post_json(
        "$rest_base_path/classes",
        [ { field => 'Name', value => 'General' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{count},             1 );
    is( $content->{page},              1 );
    is( $content->{per_page},          20 );
    is( $content->{total},             1 );
    is( scalar @{ $content->{items} }, 1 );

    my $class = $content->{items}->[0];
    is( $class->{type}, 'class' );
    is( $class->{id},   1 );
    like( $class->{_url}, qr{$rest_base_path/class/1$} );
    $class_url = $class->{_url};
}

# Class display
{
    my $res = $mech->get( $class_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},          1 );
    is( $content->{Name},        'General' );
    is( $content->{Description}, 'The default class' );
    is( $content->{Disabled},    0 );

    ok( exists $content->{$_}, "got $_" ) for qw(LastUpdated Created);

    my $links = $content->{_hyperlinks};
    is( scalar @$links, 2 );

    is( $links->[0]{ref},  'self' );
    is( $links->[0]{id},   1 );
    is( $links->[0]{type}, 'class' );
    like( $links->[0]{_url}, qr[$rest_base_path/class/1$] );

    is( $links->[1]{ref},  'create' );
    is( $links->[1]{type}, 'article' );
    like( $links->[1]{_url}, qr[$rest_base_path/article\?Class=1$] );

    my $creator = $content->{Creator};
    is( $creator->{id},   'RT_System' );
    is( $creator->{type}, 'user' );
    like( $creator->{_url}, qr{$rest_base_path/user/RT_System$} );

    my $updated_by = $content->{LastUpdatedBy};
    is( $updated_by->{id},   'RT_System' );
    is( $updated_by->{type}, 'user' );
    like( $updated_by->{_url}, qr{$rest_base_path/user/RT_System$} );
}

# Class update
{
    my $payload = {
        Name        => 'Servers',
        Description => 'gotta serve em all',
    };

    my $res = $mech->put_json( $class_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply(
        $mech->json_response,
        [   'Class General: Description changed from "The default class" to "gotta serve em all"',
            'Class Servers: Name changed from "General" to "Servers"'
        ]
    );

    $res = $mech->get( $class_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{Name},        'Servers' );
    is( $content->{Description}, 'gotta serve em all' );

    my $updated_by = $content->{LastUpdatedBy};
    is( $updated_by->{id},   'test' );
    is( $updated_by->{type}, 'user' );
    like( $updated_by->{_url}, qr{$rest_base_path/user/test$} );
}

# search Name = Servers
{
    my $res = $mech->post_json(
        "$rest_base_path/classes",
        [ { field => 'Name', value => 'Servers' } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{count},             1 );
    is( $content->{page},              1 );
    is( $content->{per_page},          20 );
    is( $content->{total},             1 );
    is( scalar @{ $content->{items} }, 1 );

    my $class = $content->{items}->[0];
    is( $class->{type}, 'class' );
    is( $class->{id},   1 );
    like( $class->{_url}, qr{$rest_base_path/class/1$} );
}

# Class delete
{
    my $res = $mech->delete( $class_url, 'Authorization' => $auth, );
    is( $res->code, 204 );

    my $class = RT::Class->new( RT->SystemUser );
    $class->Load(1);
    is( $class->Id, 1, '"deleted" class still in the database' );
    ok( $class->Disabled, '"deleted" class disabled' );

    $res = $mech->get( $class_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{Name},     'Servers' );
    is( $content->{Disabled}, 1 );
}

# Class create
my ( $laptops_url, $laptops_id );
{
    my $payload = { Name => 'Laptops', };

    my $res = $mech->post_json( "$rest_base_path/class", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( $laptops_url = $res->header('location') );
    ok( ($laptops_id) = $laptops_url =~ qr[/class/(\d+)] );
}

# Class display
{
    my $res = $mech->get( $laptops_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},       $laptops_id );
    is( $content->{Name},     'Laptops' );
    is( $content->{Disabled}, 0 );

    ok( exists $content->{$_}, "got $_" ) for qw(LastUpdated Created);

    my $links = $content->{_hyperlinks};
    is( scalar @$links, 2 );

    is( $links->[0]{ref},  'self' );
    is( $links->[0]{id},   $laptops_id );
    is( $links->[0]{type}, 'class' );
    like( $links->[0]{_url}, qr[$rest_base_path/class/$laptops_id$] );

    is( $links->[1]{ref},  'create' );
    is( $links->[1]{type}, 'article' );
    like( $links->[1]{_url}, qr[$rest_base_path/article\?Class=$laptops_id$] );

    my $creator = $content->{Creator};
    is( $creator->{id},   'test' );
    is( $creator->{type}, 'user' );
    like( $creator->{_url}, qr{$rest_base_path/user/test$} );

    my $updated_by = $content->{LastUpdatedBy};
    is( $updated_by->{id},   'test' );
    is( $updated_by->{type}, 'user' );
    like( $updated_by->{_url}, qr{$rest_base_path/user/test$} );
}

# id > 0 (finds new Laptops class but not disabled Servers class)
{
    my $res = $mech->post_json(
        "$rest_base_path/classes",
        [ { field => 'id', operator => '>', value => 0 } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{count},             1 );
    is( $content->{page},              1 );
    is( $content->{per_page},          20 );
    is( $content->{total},             1 );
    is( scalar @{ $content->{items} }, 1 );

    my $class = $content->{items}->[0];
    is( $class->{type}, 'class' );
    is( $class->{id},   $laptops_id );
    like( $class->{_url}, qr{$rest_base_path/class/$laptops_id$} );
}

done_testing;
