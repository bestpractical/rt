use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $alpha = RT::Test->load_or_create_queue( Name => 'Alpha', Description => 'Queue for test' );
my $beta  = RT::Test->load_or_create_queue( Name => 'Beta', Description => 'Queue for test' );
my $bravo = RT::Test->load_or_create_queue( Name => 'Bravo', Description => 'Queue to test sorted search' );
$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $alpha_id = $alpha->Id;
my $beta_id  = $beta->Id;
my $bravo_id = $bravo->Id;

# Name = General
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', value => 'General' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is($queue->{type}, 'queue');
    is($queue->{id}, 1);
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
}

# Name != General
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', operator => '!=', value => 'General' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my ($first, $second, $third) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $alpha_id);
    like($first->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $beta_id);
    like($second->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $bravo_id);
    like($third->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# Name STARTSWITH B
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', operator => 'STARTSWITH', value => 'B' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 2);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 2);
    is(scalar @{$content->{items}}, 2);

    my ($first, $second) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $beta_id);
    like($first->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $bravo_id);
    like($second->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# id > 2
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my ($first, $second, $third) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $alpha_id);
    like($first->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $beta_id);
    like($second->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $bravo_id);
    like($third->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

# Invalid query ({ ... })
{
    my $res = $mech->post_json("$rest_base_path/queues",
        { field => 'Name', value => 'General' },
        'Authorization' => $auth,
    );
    is($res->code, 400);

    my $content = $mech->json_response;

    TODO: {
        local $TODO = "better error reporting";
        is($content->{message}, 'Query must be an array of objects');
    }
    is($content->{message}, 'JSON object must be a ARRAY');
}

# Sorted search
{
    my $res = $mech->post_json("$rest_base_path/queues?orderby=Description&order=DESC&orderby=id",
        [{ field => 'Description', operator => 'LIKE', value => 'test' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my ($first, $second, $third) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $bravo_id);
    like($first->{_url}, qr{$rest_base_path/queue/$bravo_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $alpha_id);
    like($second->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($third->{type}, 'queue');
    is($third->{id}, $beta_id);
    like($third->{_url}, qr{$rest_base_path/queue/$beta_id$});
}

# Aggregate conditions with OR, Queues defaults to AND
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [
            { field => 'id', operator => '>', value => 2 },
            { entry_aggregator => 'OR', field => 'id', operator => '<', value => 4 },
        ],
        'Authorization' => $auth,
    );

    my $content = $mech->json_response;
    is($content->{count}, 4);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 4);
    is(scalar @{$content->{items}}, 4);
    my @ids = sort map {$_->{id}} @{$content->{items}};
    is_deeply(\@ids, [1, $alpha_id, $beta_id, $bravo_id]);
}

# Aggregate conditions with AND, Queues defaults to AND
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [
            { field => 'id', operator => '>', value => 2 },
            { field => 'id', operator => '<', value => 4 },
        ],
        'Authorization' => $auth,
    );

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $alpha_id);
}

my $cf1 = RT::Test->load_or_create_custom_field(Name  => 'cf1', Type  => 'FreeformSingle', Queue => 'General');
my $cf2 = RT::Test->load_or_create_custom_field(Name  => 'cf2', Type  => 'FreeformSingle', Queue => 'General');
my $cf3 = RT::Test->load_or_create_custom_field(Name  => 'cf3', Type  => 'FreeformSingle', Queue => 'General');
# Aggregate conditions with OR, CustomFields defaults to OR
{
    my $res = $mech->post_json("$rest_base_path/customfields",
        [
            { field => 'id', operator => '>', value => 2 },
            { field => 'id', operator => '<', value => 4 },
        ],
        'Authorization' => $auth,
    );

    my $content = $mech->json_response;
    is($content->{count}, 4);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 4);
    is(scalar @{$content->{items}}, 4);
    my @ids = sort map {$_->{id}} @{$content->{items}};
    is_deeply(\@ids, [1, 2, 3, 4]);
}

# Aggregate conditions with AND, CustomFields defaults to OR
{
    my $res = $mech->post_json("$rest_base_path/customfields",
        [
            { field => 'id', operator => '>', value => 2 },
            { entry_aggregator => 'AND', field => 'id', operator => '<', value => 4 },
        ],
        'Authorization' => $auth,
    );

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, 3);
}

# Find disabled row
{
    $alpha->SetDisabled(1);

    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 2);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 2);
    is(scalar @{$content->{items}}, 2);

    my ($first, $second) = @{ $content->{items} };
    is($first->{type}, 'queue');
    is($first->{id}, $beta_id);
    like($first->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($second->{type}, 'queue');
    is($second->{id}, $bravo_id);
    like($second->{_url}, qr{$rest_base_path/queue/$bravo_id$});

    my $res_disabled = $mech->post_json("$rest_base_path/queues?find_disabled_rows=1",
        [{ field => 'id', operator => '>', value => 2 }],
        'Authorization' => $auth,
    );
    is($res_disabled->code, 200);

    my $content_disabled = $mech->json_response;
    is($content_disabled->{count}, 3);
    is($content_disabled->{page}, 1);
    is($content_disabled->{per_page}, 20);
    is($content_disabled->{total}, 3);
    is(scalar @{$content_disabled->{items}}, 3);

    my ($first_disabled, $second_disabled, $third_disabled) = @{ $content_disabled->{items} };
    is($first_disabled->{type}, 'queue');
    is($first_disabled->{id}, $alpha_id);
    like($first_disabled->{_url}, qr{$rest_base_path/queue/$alpha_id$});

    is($second_disabled->{type}, 'queue');
    is($second_disabled->{id}, $beta_id);
    like($second_disabled->{_url}, qr{$rest_base_path/queue/$beta_id$});

    is($third_disabled->{type}, 'queue');
    is($third_disabled->{id}, $bravo_id);
    like($third_disabled->{_url}, qr{$rest_base_path/queue/$bravo_id$});
}

done_testing;

