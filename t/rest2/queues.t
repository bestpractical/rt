use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $queue_obj = RT::Test->load_or_create_queue(
    Name              => "General",
    CorrespondAddress => 'general@example.com',
    CommentAddress    => 'comment@example.com',
);

my $single_cf = RT::CustomField->new( RT->SystemUser );

my ($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', LookupType => RT::Queue->CustomFieldLookupType );
ok($ok, $msg);

($ok, $msg) = $single_cf->AddToObject($queue_obj);
ok($ok, $msg);
my $single_cf_id = $single_cf->Id;

my $single_ticket_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $single_ticket_cf->Create( Name => 'SingleTicket', Type => 'FreeformSingle', Queue => $queue_obj->Id );
ok($ok, $msg);
my $single_ticket_cf_id = $single_ticket_cf->Id;

my $single_txn_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $single_txn_cf->Create( Name => 'SingleTxn', Type => 'FreeformSingle', LookupType => RT::Transaction->CustomFieldLookupType );
ok($ok, $msg);

($ok, $msg) = $single_txn_cf->AddToObject($queue_obj);
ok($ok, $msg);
my $single_txn_cf_id = $single_txn_cf->Id;

my $queue_url;
# search Name = General
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
    $queue_url = $queue->{_url};
}

# Queue display
{
    my $res = $mech->get($queue_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, 1);
    is($content->{Name}, 'General');
    is($content->{Description}, 'The default queue');
    is($content->{Lifecycle}, 'default');
    is($content->{Disabled}, 0);

    my @fields = qw(LastUpdated Created CorrespondAddress CommentAddress SortOrder SLADisabled);
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 6);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'queue');
    like($links->[0]{_url}, qr[$rest_base_path/queue/1$]);

    is($links->[1]{ref}, 'customfield');
    like($links->[1]{_url}, qr[$rest_base_path/customfield/$single_cf_id$]);
    is($links->[1]{name}, 'Single');

    is($links->[2]{ref}, 'history');
    like($links->[2]{_url}, qr[$rest_base_path/queue/1/history$]);

    is($links->[2]{ref}, 'history');
    like($links->[2]{_url}, qr[$rest_base_path/queue/1/history$]);

    is($links->[3]{ref}, 'create');
    is($links->[3]{type}, 'ticket');
    like($links->[3]{_url}, qr[$rest_base_path/ticket\?Queue=1$]);

    my $creator = $content->{Creator};
    is($creator->{id}, 'RT_System');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/RT_System$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'RT_System');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/RT_System$});

    is_deeply($content->{Cc}, [], 'no Ccs set');
    is_deeply($content->{AdminCc}, [], 'no AdminCcs set');

    my $tix_cfs = $content->{TicketCustomFields};
    is( $tix_cfs->[0]{id}, $single_ticket_cf_id, 'Returned custom field ' . $single_ticket_cf->Name . ' applied to queue' );

    my $txn_cfs = $content->{TicketTransactionCustomFields};
    is( $txn_cfs->[0]{id}, $single_txn_cf_id, 'Returned custom field ' . $single_txn_cf->Name . ' applied to queue' );

    ok(!exists($content->{Owner}), 'no Owner at the queue level');
    ok(!exists($content->{Requestor}), 'no Requestor at the queue level');
}

# Queue update
{
    my $payload = {
        Name => 'Bugs',
        Description => 'gotta squash em all',
    };

    my $res = $mech->put_json($queue_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ['Queue 1: Description changed from "The default queue" to "gotta squash em all"', 'Queue 1: Name changed from "General" to "Bugs"']);

    $res = $mech->get($queue_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Bugs');
    is($content->{Description}, 'gotta squash em all');

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});
}

# search Name = Bugs
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', value => 'Bugs' }],
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

# Queue delete
{
    my $res = $mech->delete($queue_url,
        'Authorization' => $auth,
    );
    is($res->code, 204);

    my $queue = RT::Queue->new(RT->SystemUser);
    $queue->Load(1);
    is($queue->Id, 1, '"deleted" queue still in the database');
    ok($queue->Disabled, '"deleted" queue disabled');

    $res = $mech->get($queue_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Bugs');
    is($content->{Disabled}, 1);

    diag 'Try to call delete on a disabled queue';
    $res = $mech->delete($queue_url,
        'Authorization' => $auth,
    );
    is($res->code, 204);
}

# Queue create
my ($features_url, $features_id);
{
    my $payload = {
        Name => 'Features',
        CorrespondAddress => 'features@example.com',
        CommentAddress => 'comment@example.com',
    };

    my $res = $mech->post_json("$rest_base_path/queue",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($features_url = $res->header('location'));
    ok(($features_id) = $features_url =~ qr[/queue/(\d+)]);
}

# Queue display
{
    my $res = $mech->get($features_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $features_id);
    is($content->{Name}, 'Features');
    is($content->{Lifecycle}, 'default');
    is($content->{Disabled}, 0);

    my @fields = qw(LastUpdated Created CorrespondAddress CommentAddress SortOrder SLADisabled);
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 5);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $features_id);
    is($links->[0]{type}, 'queue');
    like($links->[0]{_url}, qr[$rest_base_path/queue/$features_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/queue/$features_id/history$]);

    is($links->[2]{ref}, 'create');
    is($links->[2]{type}, 'ticket');
    like($links->[2]{_url}, qr[$rest_base_path/ticket\?Queue=$features_id$]);

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $updated_by = $content->{LastUpdatedBy};
    is($updated_by->{id}, 'test');
    is($updated_by->{type}, 'user');
    like($updated_by->{_url}, qr{$rest_base_path/user/test$});

    is_deeply($content->{Cc}, [], 'no Ccs set');
    is_deeply($content->{AdminCc}, [], 'no AdminCcs set');

    ok(!exists($content->{Owner}), 'no Owner at the queue level');
    ok(!exists($content->{Requestor}), 'no Requestor at the queue level');
}

# id > 0 (finds new Features queue but not disabled Bugs queue)
{
    my $res = $mech->post_json("$rest_base_path/queues",
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

    my $queue = $content->{items}->[0];
    is($queue->{type}, 'queue');
    is($queue->{id}, $features_id);
    like($queue->{_url}, qr{$rest_base_path/queue/$features_id$});
}

# id > 0 (finds new Features queue but not disabled Bugs queue), include Name field
{
    my $res = $mech->post_json("$rest_base_path/queues?fields=Name",
        [{ field => 'id', operator => '>', value => 0 }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is($queue->{Name}, 'Features');
    is(scalar keys %$queue, 4);
}


# all queues, basic fields
{
    my $res = $mech->post_json("$rest_base_path/queues/all",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is(scalar keys %$queue, 3);
}

# all queues, basic fields plus Name
{
    my $res = $mech->post_json("$rest_base_path/queues/all?fields=Name",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is(scalar keys %$queue, 4);
    is($queue->{Name}, 'Features');
}

# all queues, basic fields plus Name, Lifecycle. Lifecycle should be empty
# string as we don't allow returning it.
{
    my $res = $mech->post_json("$rest_base_path/queues/all?fields=Name,Lifecycle",
        [],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is(scalar keys %$queue, 5);
    is($queue->{Name}, 'Features');
    is_deeply($queue->{Lifecycle}, 'default', 'Lifecycle is default');
}

# -- Queue watchers / role members --

my $watcher_queue = RT::Queue->new( RT->SystemUser );
($ok, $msg) = $watcher_queue->Create( Name => 'Watcher Test Queue' );
ok( $ok, "Created watcher test queue: $msg" );
my $watcher_queue_id = $watcher_queue->Id;
my $watcher_queue_url = "$rest_base_path/queue/$watcher_queue_id";

# Create test users
my $user1 = RT::User->new( RT->SystemUser );
($ok, $msg) = $user1->Create( Name => 'watcher1@example.com', EmailAddress => 'watcher1@example.com' );
ok( $ok, "Created user1: $msg" );

my $user2 = RT::User->new( RT->SystemUser );
($ok, $msg) = $user2->Create( Name => 'watcher2@example.com', EmailAddress => 'watcher2@example.com' );
ok( $ok, "Created user2: $msg" );

# Create a test group
my $group = RT::Group->new( RT->SystemUser );
($ok, $msg) = $group->CreateUserDefinedGroup( Name => 'Queue Watcher Group' );
ok( $ok, "Created group: $msg" );
my $group_id = $group->Id;

diag "Queue starts with empty Cc and AdminCc";
{
    my $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    is( $res->code, 200 );
    my $content = $mech->json_response;
    cmp_deeply( $content->{Cc}, [], 'no Cc' );
    cmp_deeply( $content->{AdminCc}, [], 'no AdminCc' );
}

diag "PUT to add Cc and AdminCc members";
{
    my $payload = {
        Cc      => ['watcher1@example.com'],
        AdminCc => ['watcher2@example.com'],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200, 'PUT to add watchers' );
    cmp_deeply( $mech->json_response, bag(
        re(qr/Added watcher1\@example.com as( a)? Cc for this queue/),
        re(qr/Added watcher2\@example.com as( a)? AdminCc for this queue/),
    ), 'got expected messages' );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{Cc}, [{
        type => 'user',
        id   => 'watcher1@example.com',
        _url => re(qr{$rest_base_path/user/watcher1\@example\.com$}),
    }], 'Cc set' );

    cmp_deeply( $content->{AdminCc}, [{
        type => 'user',
        id   => 'watcher2@example.com',
        _url => re(qr{$rest_base_path/user/watcher2\@example\.com$}),
    }], 'AdminCc set' );
}

diag "PUT replaces role members (not appends)";
{
    my $payload = {
        Cc => ['watcher2@example.com'],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{Cc}, [{
        type => 'user',
        id   => 'watcher2@example.com',
        _url => re(qr{$rest_base_path/user/watcher2\@example\.com$}),
    }], 'Cc replaced to watcher2' );
}

diag "PUT with multiple members in a role";
{
    my $payload = {
        Cc => ['watcher1@example.com', 'watcher2@example.com'],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{Cc}, bag(
        { type => 'user', id => 'watcher1@example.com',
          _url => re(qr{$rest_base_path/user/watcher1\@example\.com$}) },
        { type => 'user', id => 'watcher2@example.com',
          _url => re(qr{$rest_base_path/user/watcher2\@example\.com$}) },
    ), 'two Cc members' );
}

diag "PUT with empty array clears role members";
{
    my $payload = {
        Cc      => [],
        AdminCc => [],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{Cc}, [], 'Cc cleared' );
    cmp_deeply( $content->{AdminCc}, [], 'AdminCc cleared' );
}

diag "PUT with group as watcher";
{
    my $payload = {
        AdminCc => [$group->PrincipalId],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{AdminCc}, [{
        type => 'group',
        id   => $group_id,
        _url => re(qr{$rest_base_path/group/$group_id$}),
    }], 'group AdminCc' );
}

diag "PUT with mixed user and group";
{
    my $payload = {
        AdminCc => [$group->PrincipalId, 'watcher1@example.com'],
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{AdminCc}, bag(
        { type => 'group', id => $group_id,
          _url => re(qr{$rest_base_path/group/$group_id$}) },
        { type => 'user', id => 'watcher1@example.com',
          _url => re(qr{$rest_base_path/user/watcher1\@example\.com$}) },
    ), 'mixed user and group AdminCc' );

    # Clean up
    $mech->put_json( $watcher_queue_url,
        { AdminCc => [] }, 'Authorization' => $auth );
}

# -- Custom roles on queues --
# Note: Single-value custom roles are ACLOnly at the queue level (like Owner),
# so they don't appear as queue watchers — only multi-value custom roles do.

my $multi_role = RT::CustomRole->new( RT->SystemUser );
($ok, $msg) = $multi_role->Create( Name => 'Queue Multi Role' );
ok( $ok, "Created multi custom role: $msg" );
($ok, $msg) = $multi_role->AddToObject( $watcher_queue->Id );
ok( $ok, "Applied multi role to queue: $msg" );

# Also create a single-value role to confirm it does NOT appear
my $single_role = RT::CustomRole->new( RT->SystemUser );
($ok, $msg) = $single_role->Create( Name => 'Queue Single Role', MaxValues => 1 );
ok( $ok, "Created single custom role: $msg" );
($ok, $msg) = $single_role->AddToObject( $watcher_queue->Id );
ok( $ok, "Applied single role to queue: $msg" );

diag "Multi custom role appears in queue response; single does not";
{
    my $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    is( $res->code, 200 );
    my $content = $mech->json_response;

    ok( exists $content->{CustomRoles}, 'CustomRoles key exists' );
    cmp_deeply( $content->{CustomRoles}{'Queue Multi Role'}, [],
        'multi custom role defaults to empty' );
    ok( !exists $content->{CustomRoles}{'Queue Single Role'},
        'single custom role not in queue response (ACLOnly at queue level)' );
}

diag "PUT to set multi custom role members";
{
    my $payload = {
        'CustomRoles' => {
            'Queue Multi Role' => ['watcher1@example.com', 'watcher2@example.com'],
        },
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200, 'PUT to set multi custom role' );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{CustomRoles}{'Queue Multi Role'}, bag(
        { type => 'user', id => 'watcher1@example.com',
          _url => re(qr{$rest_base_path/user/watcher1\@example\.com$}) },
        { type => 'user', id => 'watcher2@example.com',
          _url => re(qr{$rest_base_path/user/watcher2\@example\.com$}) },
    ), 'multi custom role members set' );
}

diag "PUT replaces multi custom role members";
{
    my $payload = {
        'CustomRoles' => {
            'Queue Multi Role' => ['watcher2@example.com'],
        },
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{CustomRoles}{'Queue Multi Role'}, [{
        type => 'user',
        id   => 'watcher2@example.com',
        _url => re(qr{$rest_base_path/user/watcher2\@example\.com$}),
    }], 'multi custom role replaced' );
}

diag "PUT to clear multi custom role";
{
    my $payload = {
        'CustomRoles' => {
            'Queue Multi Role' => [],
        },
    };
    my $res = $mech->put_json( $watcher_queue_url, $payload, 'Authorization' => $auth );
    is( $res->code, 200 );

    $res = $mech->get( $watcher_queue_url, 'Authorization' => $auth );
    my $content = $mech->json_response;
    cmp_deeply( $content->{CustomRoles}{'Queue Multi Role'}, [],
        'multi custom role cleared' );
}

done_testing;
