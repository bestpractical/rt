use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

BEGIN {
    plan skip_all => 'RT 4.4 required'
        unless RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
}

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

# Empty DB
{
    my $res = $mech->post_json("$rest_base_path/assets",
        [{ field => 'id', operator => '>', value => 0 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{count}, 0);
}

# Missing Catalog
{
    my $res = $mech->post_json("$rest_base_path/asset",
        {
            Name => 'Asset creation using REST',
        },
        'Authorization' => $auth,
    );
    is($res->code, 400);
    is($mech->json_response->{message}, 'Invalid Catalog');
}

# Asset Creation
my ($asset_url, $asset_id);
{
    my $payload = {
        Name    => 'Asset creation using REST',
        Catalog => 'General assets',
        Content => 'Testing asset creation using REST API.',
    };

    # Rights Test - No CreateAsset
    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    # Rights Test - With CreateAsset
    $user->PrincipalObj->GrantRight( Right => 'CreateAsset' );
    $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($asset_url = $res->header('location'));
    ok(($asset_id) = $asset_url =~ qr[/asset/(\d+)]);
}

# Asset Display
{
    # Rights Test - No ShowAsset
    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowAsset
{
    $user->PrincipalObj->GrantRight( Right => 'ShowAsset' );

    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $asset_id);
    is($content->{Name}, 'Asset creation using REST');
    is($content->{Status}, 'new');
    is($content->{Name}, 'Asset creation using REST');

    ok(exists $content->{$_}) for qw(Creator Created LastUpdated LastUpdatedBy
                                     HeldBy Contact
                                     Description);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'asset');
    like($links->[0]{_url}, qr[$rest_base_path/asset/$asset_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/asset/$asset_id/history$]);

    my $catalog = $content->{Catalog};
    is($catalog->{id}, 1);
    is($catalog->{type}, 'catalog');
    like($catalog->{_url}, qr{$rest_base_path/catalog/1$});

    my $owner = $content->{Owner};
    is($owner->{id}, 'Nobody');
    is($owner->{type}, 'user');
    like($owner->{_url}, qr{$rest_base_path/user/Nobody$});

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});
}

# Asset Search
{
    my $res = $mech->post_json("$rest_base_path/assets",
        [{ field => 'id', operator => '>', value => 0 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $asset = $content->{items}->[0];
    is($asset->{type}, 'asset');
    is($asset->{id}, 1);
    like($asset->{_url}, qr{$rest_base_path/asset/1$});
}

# Asset Update
{
    my $payload = {
        Name   => 'Asset update using REST',
        Status => 'allocated',
    };

    # Rights Test - No ModifyAsset
    my $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Asset Asset creation using REST: Permission Denied', 'Asset Asset creation using REST: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyAsset' );

    $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Asset Asset update using REST: Name changed from 'Asset creation using REST' to 'Asset update using REST'", "Asset Asset update using REST: Status changed from 'new' to 'allocated'"]);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Asset update using REST');
    is($content->{Status}, 'allocated');

    # now that we have ModifyAsset, we should have additional hypermedia
    my $links = $content->{_hyperlinks};
    is(scalar @$links, 5);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'asset');
    like($links->[0]{_url}, qr[$rest_base_path/asset/$asset_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/asset/$asset_id/history$]);

    is($links->[2]{ref}, 'lifecycle');
    like($links->[2]{_url}, qr[$rest_base_path/asset/$asset_id$]);
    is($links->[2]{label}, 'Now in-use');
    is($links->[2]{from}, '*');
    is($links->[2]{to}, 'in-use');

    is($links->[3]{ref}, 'lifecycle');
    like($links->[3]{_url}, qr[$rest_base_path/asset/$asset_id$]);
    is($links->[3]{label}, 'Recycle');
    is($links->[3]{from}, '*');
    is($links->[3]{to}, 'recycled');

    is($links->[4]{ref}, 'lifecycle');
    like($links->[4]{_url}, qr[$rest_base_path/asset/$asset_id$]);
    is($links->[4]{label}, 'Report stolen');
    is($links->[4]{from}, '*');
    is($links->[4]{to}, 'stolen');

    # update again with no changes
    $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, []);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{Name}, 'Asset update using REST');
    is($content->{Status}, 'allocated');
}

# Transactions
{
    my $res = $mech->get($asset_url,
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

    for my $txn (@{ $content->{items} }) {
        is($txn->{type}, 'transaction');
        like($txn->{_url}, qr{$rest_base_path/transaction/\d+$});
    }
}

done_testing;
