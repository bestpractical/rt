use strict;
use warnings;
use RT::Test::REST2 tests => undef;

BEGIN {
    plan skip_all => 'RT 4.4 required'
        unless RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
}

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $catalog_url;
# search Name = General assets
{
    my $res = $mech->post_json("$rest_base_path/catalogs",
        [{ field => 'Name', value => 'General assets' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $catalog = $content->{items}->[0];
    is($catalog->{type}, 'catalog');
    is($catalog->{id}, 1);
    like($catalog->{_url}, qr{$rest_base_path/catalog/1$});
    $catalog_url = $catalog->{_url};
}

# Catalog display
{
    my $res = $mech->get($catalog_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, 1);
    is($content->{Name}, 'General assets');
    is($content->{Description}, 'The default catalog');
    is($content->{Lifecycle}, 'assets');
    is($content->{Disabled}, 0);

    ok(exists $content->{$_}, "got $_") for qw(LastUpdated Created);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'catalog');
    like($links->[0]{_url}, qr[$rest_base_path/catalog/1$]);

    is($links->[1]{ref}, 'create');
    is($links->[1]{type}, 'asset');
    like($links->[1]{_url}, qr[$rest_base_path/asset\?Catalog=1$]);

    my $creator = $content->{Creator};
    is($creator->{id}, 'RT_System');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/RT_System$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'RT_System');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/RT_System$});

    is_deeply($content->{Contact}, [], 'no Contact set');
    is_deeply($content->{HeldBy}, [], 'no HeldBy set');

    ok(!exists($content->{Owner}), 'no Owner at the catalog level');
}

# Catalog update
{
    my $payload = {
        Name => 'Servers',
        Description => 'gotta serve em all',
    };

    my $res = $mech->put_json($catalog_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Catalog General assets: Description changed from 'The default catalog' to 'gotta serve em all'", "Catalog Servers: Name changed from 'General assets' to 'Servers'"]);

    $res = $mech->get($catalog_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Servers');
    is($content->{Description}, 'gotta serve em all');

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});
}

# search Name = Servers
{
    my $res = $mech->post_json("$rest_base_path/catalogs",
        [{ field => 'Name', value => 'Servers' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $catalog = $content->{items}->[0];
    is($catalog->{type}, 'catalog');
    is($catalog->{id}, 1);
    like($catalog->{_url}, qr{$rest_base_path/catalog/1$});
}

# Catalog delete
{
    my $res = $mech->delete($catalog_url,
        'Authorization' => $auth,
    );
    is($res->code, 204);

    my $catalog = RT::Catalog->new(RT->SystemUser);
    $catalog->Load(1);
    is($catalog->Id, 1, '"deleted" catalog still in the database');
    ok($catalog->Disabled, '"deleted" catalog disabled');

    $res = $mech->get($catalog_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Servers');
    is($content->{Disabled}, 1);
}

# Catalog create
my ($laptops_url, $laptops_id);
{
    my $payload = {
        Name => 'Laptops',
    };

    my $res = $mech->post_json("$rest_base_path/catalog",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($laptops_url = $res->header('location'));
    ok(($laptops_id) = $laptops_url =~ qr[/catalog/(\d+)]);
}

# Catalog display
{
    my $res = $mech->get($laptops_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $laptops_id);
    is($content->{Name}, 'Laptops');
    is($content->{Lifecycle}, 'assets');
    is($content->{Disabled}, 0);

    ok(exists $content->{$_}, "got $_") for qw(LastUpdated Created);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $laptops_id);
    is($links->[0]{type}, 'catalog');
    like($links->[0]{_url}, qr[$rest_base_path/catalog/$laptops_id$]);

    is($links->[1]{ref}, 'create');
    is($links->[1]{type}, 'asset');
    like($links->[1]{_url}, qr[$rest_base_path/asset\?Catalog=$laptops_id$]);

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});

    is_deeply($content->{Contact}, [], 'no Contact set');
    is_deeply($content->{HeldBy}, [], 'no HeldBy set');

    ok(!exists($content->{Owner}), 'no Owner at the catalog level');
}

# id > 0 (finds new Laptops catalog but not disabled Servers catalog)
{
    my $res = $mech->post_json("$rest_base_path/catalogs",
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

    my $catalog = $content->{items}->[0];
    is($catalog->{type}, 'catalog');
    is($catalog->{id}, $laptops_id);
    like($catalog->{_url}, qr{$rest_base_path/catalog/$laptops_id$});
}

done_testing;

