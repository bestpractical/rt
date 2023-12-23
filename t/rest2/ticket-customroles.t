use strict;
use warnings;
use RT::Test::REST2 tests => undef;

use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my $single = RT::CustomRole->new(RT->SystemUser);
my ($ok, $msg) = $single->Create(Name => 'Single Member', MaxValues => 1);
ok($ok, $msg);
my $single_id = $single->Id;

($ok, $msg) = $single->AddToObject($queue->id);
ok($ok, $msg);

my $multi = RT::CustomRole->new(RT->SystemUser);
($ok, $msg) = $multi->Create(Name => 'Multi Member');
ok($ok, $msg);
my $multi_id = $multi->Id;

($ok, $msg) = $multi->AddToObject($queue->id);
ok($ok, $msg);

for my $email (qw/multi@example.com test@localhost multi2@example.com single2@example.com/) {
    my $user = RT::User->new(RT->SystemUser);
    my ($ok, $msg) = $user->Create(Name => $email, EmailAddress => $email);
    ok($ok, $msg);
}

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket ShowTicket ModifyTicket OwnTicket AdminUsers SeeGroup SeeQueue/;

# Create and view ticket with no watchers
{
    my $payload = {
        Subject => 'Ticket with no watchers',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [], 'no Multi Member');
    cmp_deeply($content->{$single->Name}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Single Member is Nobody');

    cmp_deeply(
        [grep { $_->{ref} eq 'customrole' } @{ $content->{'_hyperlinks'} }],
        [{
            ref => 'customrole',
            id  => $single_id,
            type => 'customrole',
            group_type => $single->GroupType,
            _url => re(qr[$rest_base_path/customrole/$single_id$]),
        }, {
            ref => 'customrole',
            id  => $multi_id,
            type => 'customrole',
            group_type => $multi->GroupType,
            _url => re(qr[$rest_base_path/customrole/$multi_id$]),
        }],
        'Two CF hypermedia',
    );

    my ($single_url) = map { $_->{_url} } grep { $_->{ref} eq 'customrole' && $_->{id} == $single_id } @{ $content->{'_hyperlinks'} };
    my ($multi_url) = map { $_->{_url} } grep { $_->{ref} eq 'customrole' && $_->{id} == $multi_id } @{ $content->{'_hyperlinks'} };

    $res = $mech->get($content->{$single->Name}{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id => RT->Nobody->id,
        Name => 'Nobody',
        RealName => 'Nobody in particular',
    }), 'Nobody user');

    $res = $mech->get($single_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $single_id,
        Disabled   => 0,
        MaxValues  => 1,
        Name       => 'Single Member',
    }), 'single role');

    $res = $mech->get($multi_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $multi_id,
        Disabled   => 0,
        MaxValues  => 0,
        Name       => 'Multi Member',
    }), 'multi role');
}

# Create and view ticket with single users as watchers
{
    my $payload = {
        Subject   => 'Ticket with single watchers',
        Queue     => 'General',
        $multi->GroupType  => 'multi@example.com',
        $single->GroupType => 'test@localhost',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }], 'one Multi Member');

    cmp_deeply($content->{$single->Name}, {
        type => 'user',
        id   => 'test@localhost',
        _url => re(qr{$rest_base_path/user/test\@localhost$}),
    }, 'one Single Member');
}

# Create and view ticket with multiple users as watchers
{
    my $payload = {
        Subject   => 'Ticket with multiple watchers',
        Queue     => 'General',
        $multi->GroupType  => ['multi@example.com', 'multi2@example.com'],
        $single->GroupType => ['test@localhost', 'single2@example.com'],
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }, {
        type => 'user',
        id   => 'multi2@example.com',
        _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
    }], 'two Multi Members');

    cmp_deeply($content->{$single->Name}, {
        type => 'user',
        id   => 'test@localhost',
        _url => re(qr{$rest_base_path/user/test\@localhost}),
    }, 'one Single Member');
}

diag 'Create and view ticket with custom roles by name';
{
    my $payload = {
        Subject   => 'Ticket with multiple watchers',
        Queue     => 'General',
        CustomRoles => { 'Multi Member' => ['multi@example.com', 'multi2@example.com'],
                         'Single Member' => 'test@localhost' },
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }, {
        type => 'user',
        id   => 'multi2@example.com',
        _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
    }], 'two Multi Members');

    cmp_deeply($content->{$single->Name}, {
        type => 'user',
        id   => 'test@localhost',
        _url => re(qr{$rest_base_path/user/test\@localhost}),
    }, 'one Single Member');
}

# Modify single-member role
{
    my $payload = {
        Subject   => 'Ticket for modifying Single Member',
        Queue     => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    cmp_deeply($mech->json_response->{$single->Name}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Single Member is Nobody');

    for my $identifier ($user->id, $user->Name) {
        $payload = {
            $single->GroupType => $identifier,
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Single Member changed from Nobody to test"], "updated Single Member with identifier $identifier");

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{$single->Name}, {
            type => 'user',
            id   => 'test',
            _url => re(qr{$rest_base_path/user/test$}),
        }, 'Single Member has changed to test');

        $payload = {
            $single->GroupType => 'Nobody',
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Single Member changed from test to Nobody"], 'updated Single Member');

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{$single->Name}, {
            type => 'user',
            id   => 'Nobody',
            _url => re(qr{$rest_base_path/user/Nobody$}),
        }, 'Single Member has changed to Nobody');
    }

    for my $identifier ($user->id, $user->Name) {
        $payload = {
            CustomRoles => { 'Single Member' => $identifier },
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Single Member changed from Nobody to test"], "updated Single Member with identifier $identifier");

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{$single->Name}, {
            type => 'user',
            id   => 'test',
            _url => re(qr{$rest_base_path/user/test$}),
        }, 'Single Member has changed to test');

        $payload = {
            CustomRoles => { 'Single Member' => 'Nobody' },
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Single Member changed from test to Nobody"], 'updated Single Member');

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{$single->Name}, {
            type => 'user',
            id   => 'Nobody',
            _url => re(qr{$rest_base_path/user/Nobody$}),
        }, 'Single Member has changed to Nobody');
    }
}

# Modify multi-member roles
{
    my $payload = {
        Subject => 'Ticket for modifying watchers',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [], 'no Multi Member');

    $payload = {
        $multi->GroupType => 'multi@example.com',
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is_deeply($mech->json_response, ['Added multi@example.com as Multi Member for this ticket'], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }], 'one Multi Member');

    $payload = {
        $multi->GroupType => ['multi2@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is_deeply($mech->json_response, ['Added multi2@example.com as Multi Member for this ticket', 'multi@example.com is no longer Multi Member for this ticket'], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi2@example.com',
        _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
    }], 'new Multi Member');

    $payload = {
        $multi->GroupType => ['multi@example.com', 'multi2@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is_deeply($mech->json_response, ['Added multi@example.com as Multi Member for this ticket'], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, bag({
        type => 'user',
        id   => 'multi2@example.com',
        _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
    }, {
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }), 'two Multi Member');

    my $users = RT::Users->new(RT->SystemUser);
    $users->UnLimit;
    my %user_id = map { $_->Name => $_->Id } @{ $users->ItemsArrayRef };

    my @stable_payloads = (
    {
        Subject => 'no changes to watchers',
        _messages => ["Ticket 6: Subject changed from 'Ticket for modifying watchers' to 'no changes to watchers'"],
        _name => 'no watcher keys',
    },
    {
        $multi->GroupType => ['multi@example.com', 'multi2@example.com'],
        _name => 'identical watcher values',
    },
    {
        $multi->GroupType => ['multi2@example.com', 'multi@example.com'],
        _name => 'out of order watcher values',
    },
    {
        $multi->GroupType => [$user_id{'multi2@example.com'}, $user_id{'multi@example.com'}],
        _name => 'watcher ids instead of names',
    });

    for my $payload (@stable_payloads) {
        my $messages = delete $payload->{_messages} || [];
        my $name = delete $payload->{_name} || '(undef)';

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, $messages, "watchers are preserved when $name");

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);
        $content = $mech->json_response;
        cmp_deeply($content->{$multi->Name}, bag({
            type => 'user',
            id   => 'multi2@example.com',
            _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
        }, {
            type => 'user',
            id   => 'multi@example.com',
            _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
        }), "preserved two Multi Members when $name");
    }

    $payload = { CustomRoles => { 'Multi Member' => [ 'test@localhost', 'multi@example.com' ] }, };
    $res     = $mech->put_json( $ticket_url, $payload, 'Authorization' => $auth, );
    is_deeply(
        $mech->json_response,
        [   'Added test@localhost as Multi Member for this ticket',
            'multi2@example.com is no longer Multi Member for this ticket'
        ],
        "updated ticket watchers"
    );
    $res = $mech->get( $ticket_url, 'Authorization' => $auth, );
    is( $res->code, 200 );
    $content = $mech->json_response;
    cmp_deeply(
        $content->{ $multi->Name },
        bag({   type => 'user',
                id   => 'test@localhost',
                _url => re(qr{$rest_base_path/user/test\@localhost$}),
            },
            {   type => 'user',
                id   => 'multi@example.com',
                _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
            }
        ),
        'two Multi Members'
    );
}

# groups as members
{
    my $group = RT::Group->new(RT->SystemUser);
    my ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Watcher Group');
    ok($ok, $msg);
    my $group_id = $group->Id;

    for my $email ('multi@example.com', 'multi2@example.com') {
        my $user = RT::User->new(RT->SystemUser);
        $user->LoadByEmail($email);
        $group->AddMember($user->PrincipalId);
    }

    my $payload = {
        Subject           => 'Ticket for modifying watchers',
        Queue             => 'General',
        $multi->GroupType => $group->PrincipalId,
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        id   => $group_id,
        type => 'group',
        _url => re(qr{$rest_base_path/group/$group_id$}),
    }], 'group Multi Member');

    $payload = {
        $multi->GroupType => 'multi@example.com',
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is_deeply($mech->json_response, ['Added multi@example.com as Multi Member for this ticket', 'Watcher Group is no longer Multi Member for this ticket'], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    }], 'one Multi Member user');

    $payload = {
        $multi->GroupType => [$group_id, 'multi@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is_deeply($mech->json_response, ['Added Watcher Group as Multi Member for this ticket'], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{$multi->Name}, [{
        type => 'user',
        id   => 'multi@example.com',
        _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
    },
    {
        id   => $group_id,
        type => 'group',
        _url => re(qr{$rest_base_path/group/$group_id$}),
    }], 'Multi Member user and group');

    $res = $mech->get($content->{$multi->Name}[1]{_url},
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id           => $group->Id,
        Name         => 'Watcher Group',
        Domain       => 'UserDefined',
        CustomFields => [],
        Members      => [{
            type => 'user',
            id   => 'multi@example.com',
            _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
        },
        {
            type => 'user',
            id   => 'multi2@example.com',
            _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
        }],
    }), 'fetched group');
}

{
    my $payload = {
        Subject => 'Test custom rules applied later',
        Queue   => 'General',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok(my $ticket_url = $res->header('location'));
    ok((my $ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $later_single = RT::CustomRole->new(RT->SystemUser);
    ($ok, $msg) = $later_single->Create(Name => 'Later Single Member', MaxValues => 1);
    ok($ok, $msg);
    my $later_single_id = $later_single->Id;

    ($ok, $msg) = $later_single->AddToObject($queue->id);
    ok($ok, $msg);

    my $later_multi = RT::CustomRole->new(RT->SystemUser);
    ($ok, $msg) = $later_multi->Create(Name => 'Later Multi Member');
    ok($ok, $msg);
    my $later_multi_id = $later_multi->Id;

    ($ok, $msg) = $later_multi->AddToObject($queue->id);
    ok($ok, $msg);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    cmp_deeply($content->{$later_multi->Name}, [], 'no Later Multi Member');
    cmp_deeply($content->{$later_single->Name}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Later Single Member is Nobody');
}


# Ticket Search
{

    my $payload = {
        Subject            => 'Ticket creation using REST',
        Queue              => 'General',
        Content            => 'Testing ticket creation using REST API.',
        $single->GroupType => 'single2@example.com',
        $multi->GroupType  => 'multi@example.com, multi2@example.com',
    };

    my $res = $mech->post_json( "$rest_base_path/ticket", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( my $ticket_url = $res->header('location') );
    ok( my ($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)] );

    $res = $mech->get(
        "$rest_base_path/tickets?query=id=$ticket_id&fields=" . join( ',', $single->GroupType, $multi->GroupType ),
        'Authorization' => $auth,
    );
    is( $res->code, 200 );
    my $content = $mech->json_response;
    is( scalar @{ $content->{items} }, 1 );

    my $ticket = $content->{items}->[0];
    is( $ticket->{ $single->GroupType }{id},   'single2@example.com', 'Single Member id in search result' );
    is( $ticket->{ $multi->GroupType }[0]{id}, 'multi@example.com',   'Multi Member id in search result' );
    is( $ticket->{ $multi->GroupType }[1]{id}, 'multi2@example.com',  'Multi Member id in search result' );

    $res = $mech->get( "$rest_base_path/tickets?query=id=$ticket_id&fields=CustomRoles", 'Authorization' => $auth, );
    is( $res->code, 200 );
    $content = $mech->json_response;
    is( scalar @{ $content->{items} }, 1 );

    $ticket = $content->{items}->[0];
    is( $ticket->{CustomRoles}{ $single->Name }{id}, 'single2@example.com',  'Single Member id in search result' );
    is( $ticket->{CustomRoles}{ $multi->Name }[0]{id}, 'multi@example.com',  'Multi Member id in search result' );
    is( $ticket->{CustomRoles}{ $multi->Name }[1]{id}, 'multi2@example.com', 'Multi Member id in search result' );
}

diag 'Test custom role name conflicts';
{
    my $creator = RT::CustomRole->new( RT->SystemUser );
    ( $ok, $msg ) = $creator->Create( Name => 'Creator' );
    ok( $ok, $msg );
    my $creator_id = $creator->Id;

    ( $ok, $msg ) = $creator->AddToObject( $queue->id );
    ok( $ok, $msg );

    my $payload = {
        Subject     => 'Ticket with creator watchers',
        Queue       => 'General',
        CustomRoles => { Creator => [ 'multi@example.com', 'multi2@example.com' ] },
    };

    my $res = $mech->post_json( "$rest_base_path/ticket", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( my $ticket_url = $res->header('location') );
    ok( ( my $ticket_id ) = $ticket_url =~ qr[/ticket/(\d+)] );

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    $res = $mech->get( $ticket_url, 'Authorization' => $auth, );
    is( $res->code, 200 );
    my $content = $mech->json_response;
    cmp_deeply(
        $content->{ 'CustomRole.{' . $creator->Name . '}' },
        [
            {
                type => 'user',
                id   => 'multi@example.com',
                _url => re(qr{$rest_base_path/user/multi\@example\.com$}),
            },
            {
                type => 'user',
                id   => 'multi2@example.com',
                _url => re(qr{$rest_base_path/user/multi2\@example\.com$}),
            }
        ],
        'two Creator Members'
    );
    cmp_deeply(
        $content->{Creator},
        {
            type => 'user',
            id   => 'test',
            _url => re(qr{$rest_base_path/user/test$}),
        },
        'two Multi Members'
    );
    is( scalar @warnings, 1, 'Got one warning' );
    like(
        $warnings[0],
        qr/\QCustomRole Creator conflicts with core field Creator, renaming its key to CustomRole.{Creator}\E/,
        'Got the name conflict warning'
    );

    is_deeply(
        $content->{_comments},
        [
            'Top level individual custom role keys are deprecated and will be removed in RT 5.2. Please use "CustomRoles" instead.'
        ],
        'Got the deprecated comment'
    );
}

done_testing;
