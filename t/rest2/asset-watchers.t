use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateAsset ShowAsset ModifyAsset OwnAsset AdminUsers SeeGroup/;

# Modify single user allowed roles.
{
    my $payload = {
        Name    => 'Asset creation using REST',
        Catalog => 'General assets',
        Content => 'Testing asset creation using REST API.',
    };

    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $asset_url = $res->header('location'));
    ok((my $asset_id) = $asset_url =~ qr[/asset/(\d+)]);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Owner is Nobody');

    $res = $mech->get($content->{Owner}{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id => RT->Nobody->id,
        Name => 'Nobody',
        RealName => 'Nobody in particular',
    }), 'Nobody user');

    for my $field ('Owner') {
        for my $identifier ($user->id, $user->Name) {
            $payload = {
                $field => $identifier,
            };

            $res = $mech->put_json($asset_url,
                $payload,
                'Authorization' => $auth,
            );
            is_deeply($mech->json_response, ["$field set to test"], "updated $field with identifier $identifier");

            $res = $mech->get($asset_url,
                'Authorization' => $auth,
            );
            is($res->code, 200);

            cmp_deeply($mech->json_response->{$field}, {
                type => 'user',
                id   => 'test',
                _url => re(qr{$rest_base_path/user/test$}),
            }, "$field has changed to test");

            $payload = {
                $field => 'Nobody',
            };

            $res = $mech->put_json($asset_url,
                $payload,
                'Authorization' => $auth,
            );
            is_deeply($mech->json_response, ["$field set to Nobody"], "updated $field");

            $res = $mech->get($asset_url,
                'Authorization' => $auth,
            );
            is($res->code, 200);

            cmp_deeply($mech->json_response->{$field}, {
                type => 'user',
                id   => 'Nobody',
                _url => re(qr{$rest_base_path/user/Nobody$}),
            }, "$field has changed to Nobody");
        }
    }
}

# Modify multi-user allowed roles (HeldBy)
{
    my ($asset_url, $asset_id);
    my $payload = {
        Name    => 'Asset for modifying owner using REST',
        Catalog => 'General assets',
        Content => 'Testing asset creation using REST API.',
        HeldBy  => 'root',
        Contact => 'root',
    };

    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($asset_url = $res->header('location'));
    ok(($asset_id) = $asset_url =~ qr[/asset/(\d+)]);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    # Initial sanity check.
    for my $field ('Contact', 'HeldBy') {
        cmp_deeply($mech->json_response->{$field}, [{
            type => 'user',
            id   => 'root',
            _url => re(qr{$rest_base_path/user/root$}),
        }], "$field is root");
        }

    for my $field ('Contact', 'HeldBy') {
        for my $identifier ($user->id, $user->Name) {
            my $payload = {
                $field => $identifier,
            };

            $res = $mech->put_json($asset_url,
                $payload,
                'Authorization' => $auth,
            );
            is_deeply($mech->json_response, ["Member added: test", 'Member deleted'], "updated $field with identifier $identifier");

            $res = $mech->get($asset_url,
                'Authorization' => $auth,
            );
            is($res->code, 200);

            cmp_deeply($mech->json_response->{$field}, [{
                type => 'user',
                id   => 'test',
                _url => re(qr{$rest_base_path/user/test$}),
            }], "$field has changed to test");

            $payload = {
                $field => 'Nobody',
            };

            $res = $mech->put_json($asset_url,
                $payload,
                'Authorization' => $auth,
            );
            is_deeply($mech->json_response, ["Member added: Nobody", 'Member deleted'], "updated $field");

            $res = $mech->get($asset_url,
                'Authorization' => $auth,
            );
            is($res->code, 200);

            cmp_deeply($mech->json_response->{$field}, [{
                type => 'user',
                id   => 'Nobody',
                _url => re(qr{$rest_base_path/user/Nobody$}),
            }], "$field has changed to Nobody");
        }
    }
}

done_testing;
