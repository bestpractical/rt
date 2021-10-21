use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket ShowTicket ModifyTicket OwnTicket AdminUsers SeeGroup/;

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
    cmp_deeply($content->{Requestor}, [], 'no Requestor');
    cmp_deeply($content->{Cc}, [], 'no Cc');
    cmp_deeply($content->{AdminCc}, [], 'no AdminCc');
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
}

# Create and view ticket with single users as watchers
{
    my $payload = {
        Subject   => 'Ticket with single watchers',
        Queue     => 'General',
        Requestor => 'requestor@example.com',
        Cc        => 'cc@example.com',
        AdminCc   => 'admincc@example.com',
        Owner     => $user->PrincipalId,
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
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }], 'one Requestor');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }], 'one Cc');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }], 'one AdminCc');

    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'test',
        _url => re(qr{$rest_base_path/user/test$}),
    }, 'Owner is REST test user');
}

# Create and view ticket with multiple users as watchers
{
    my $payload = {
        Subject   => 'Ticket with multiple watchers',
        Queue     => 'General',
        Requestor => ['requestor@example.com', 'requestor2@example.com'],
        Cc        => ['cc@example.com', 'cc2@example.com'],
        AdminCc   => ['admincc@example.com', 'admincc2@example.com'],
        Owner     => $user->PrincipalId,
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
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }, {
        type => 'user',
        id   => 'requestor2@example.com',
        _url => re(qr{$rest_base_path/user/requestor2\@example\.com$}),
    }], 'two Requestors');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }, {
        type => 'user',
        id   => 'cc2@example.com',
        _url => re(qr{$rest_base_path/user/cc2\@example\.com$}),
    }], 'two Ccs');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }, {
        type => 'user',
        id   => 'admincc2@example.com',
        _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
    }], 'two AdminCcs');

    cmp_deeply($content->{Owner}, {
        type => 'user',
        id   => 'test',
        _url => re(qr{$rest_base_path/user/test$}),
    }, 'Owner is REST test user');
}

# Modify owner
{
    my $payload = {
        Subject   => 'Ticket for modifying owner',
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

    cmp_deeply($mech->json_response->{Owner}, {
        type => 'user',
        id   => 'Nobody',
        _url => re(qr{$rest_base_path/user/Nobody$}),
    }, 'Owner is Nobody');

    for my $identifier ($user->id, $user->Name) {
        $payload = {
            Owner => $identifier,
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Ticket $ticket_id: Owner changed from Nobody to test"], "updated Owner with identifier $identifier");

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{Owner}, {
            type => 'user',
            id   => 'test',
            _url => re(qr{$rest_base_path/user/test$}),
        }, 'Owner has changed to test');

        $payload = {
            Owner => 'Nobody',
        };

        $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is_deeply($mech->json_response, ["Ticket $ticket_id: Owner changed from test to Nobody"], 'updated Owner');

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        cmp_deeply($mech->json_response->{Owner}, {
            type => 'user',
            id   => 'Nobody',
            _url => re(qr{$rest_base_path/user/Nobody$}),
        }, 'Owner has changed to Nobody');
    }
}

# Modify multi-member roles
{
    my $payload = {
        Subject   => 'Ticket for modifying watchers',
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

    my $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [], 'no Requestor');
    cmp_deeply($content->{Cc}, [], 'no Cc');
    cmp_deeply($content->{AdminCc}, [], 'no AdminCc');

    $payload = {
        Requestor => 'requestor@example.com',
        Cc        => 'cc@example.com',
        AdminCc   => 'admincc@example.com',
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    cmp_deeply($mech->json_response, [
        re(qr/Added admincc\@example.com as( a)? AdminCc for this ticket/),
        re(qr/Added cc\@example.com as( a)? Cc for this ticket/),
        re(qr/Added requestor\@example.com as( a)? Requestor for this ticket/)
    ], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }], 'one Requestor');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }], 'one Cc');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }], 'one AdminCc');

    $payload = {
        Requestor => ['requestor2@example.com'],
        Cc        => ['cc2@example.com'],
        AdminCc   => ['admincc2@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    cmp_deeply($mech->json_response, [
        re(qr/Added admincc2\@example.com as( a)? AdminCc for this ticket/),
        re(qr/admincc\@example.com is no longer( a)? AdminCc for this ticket/),
        re(qr/Added cc2\@example.com as( a)? Cc for this ticket/),
        re(qr/cc\@example.com is no longer( a)? Cc for this ticket/),
        re(qr/Added requestor2\@example.com as( a)? Requestor for this ticket/),
        re(qr/requestor\@example.com is no longer( a)? Requestor for this ticket/),
    ], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, [{
        type => 'user',
        id   => 'requestor2@example.com',
        _url => re(qr{$rest_base_path/user/requestor2\@example\.com$}),
    }], 'new Requestor');

    cmp_deeply($content->{Cc}, [{
        type => 'user',
        id   => 'cc2@example.com',
        _url => re(qr{$rest_base_path/user/cc2\@example\.com$}),
    }], 'new Cc');

    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc2@example.com',
        _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
    }], 'new AdminCc');

    $payload = {
        Requestor => ['requestor@example.com', 'requestor2@example.com'],
        Cc        => ['cc@example.com', 'cc2@example.com'],
        AdminCc   => ['admincc@example.com', 'admincc2@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    cmp_deeply($mech->json_response, [
        re(qr/Added admincc\@example.com as( a)? AdminCc for this ticket/),
        re(qr/Added cc\@example.com as( a)? Cc for this ticket/),
        re(qr/Added requestor\@example.com as( a)? Requestor for this ticket/)
    ], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{Requestor}, bag({
        type => 'user',
        id   => 'requestor2@example.com',
        _url => re(qr{$rest_base_path/user/requestor2\@example\.com$}),
    }, {
        type => 'user',
        id   => 'requestor@example.com',
        _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
    }), 'two Requestors');

    cmp_deeply($content->{Cc}, bag({
        type => 'user',
        id   => 'cc2@example.com',
        _url => re(qr{$rest_base_path/user/cc2\@example\.com$}),
    }, {
        type => 'user',
        id   => 'cc@example.com',
        _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
    }), 'two Ccs');

    cmp_deeply($content->{AdminCc}, bag({
        type => 'user',
        id   => 'admincc2@example.com',
        _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
    }, {
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }), 'two AdminCcs');

    my $users = RT::Users->new(RT->SystemUser);
    $users->UnLimit;
    my %user_id = map { $_->Name => $_->Id } @{ $users->ItemsArrayRef };

    my @stable_payloads = (
    {
        Subject => 'no changes to watchers',
        _messages => ["Ticket 5: Subject changed from 'Ticket for modifying watchers' to 'no changes to watchers'"],
        _name => 'no watcher keys',
    },
    {
        Requestor => ['requestor@example.com', 'requestor2@example.com'],
        Cc        => ['cc@example.com', 'cc2@example.com'],
        AdminCc   => ['admincc@example.com', 'admincc2@example.com'],
        _name     => 'identical watcher values',
    },
    {
        Requestor => ['requestor2@example.com', 'requestor@example.com'],
        Cc        => ['cc2@example.com', 'cc@example.com'],
        AdminCc   => ['admincc2@example.com', 'admincc@example.com'],
        _name     => 'out of order watcher values',
    },
    {
        Requestor => [$user_id{'requestor2@example.com'}, $user_id{'requestor@example.com'}],
        Cc        => [$user_id{'cc2@example.com'}, $user_id{'cc@example.com'}],
        AdminCc   => [$user_id{'admincc2@example.com'}, $user_id{'admincc@example.com'}],
        _name     => 'watcher ids instead of names',
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
        cmp_deeply($content->{Requestor}, bag({
            type => 'user',
            id   => 'requestor2@example.com',
            _url => re(qr{$rest_base_path/user/requestor2\@example\.com$}),
        }, {
            type => 'user',
            id   => 'requestor@example.com',
            _url => re(qr{$rest_base_path/user/requestor\@example\.com$}),
        }), "preserved two Requestors when $name");

        cmp_deeply($content->{Cc}, bag({
            type => 'user',
            id   => 'cc2@example.com',
            _url => re(qr{$rest_base_path/user/cc2\@example\.com$}),
        }, {
            type => 'user',
            id   => 'cc@example.com',
            _url => re(qr{$rest_base_path/user/cc\@example\.com$}),
        }), "preserved two Ccs when $name");

        cmp_deeply($content->{AdminCc}, bag({
            type => 'user',
            id   => 'admincc2@example.com',
            _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
        }, {
            type => 'user',
            id   => 'admincc@example.com',
            _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
        }), "preserved two AdminCcs when $name");
    }
}

# groups as members
{
    my $group = RT::Group->new(RT->SystemUser);
    my ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Watcher Group');
    ok($ok, $msg);
    my $group_id = $group->Id;

    for my $email ('admincc@example.com', 'admincc2@example.com') {
        my $user = RT::User->new(RT->SystemUser);
        $user->LoadByEmail($email);
        $group->AddMember($user->PrincipalId);
    }

    my $payload = {
        Subject   => 'Ticket for modifying watchers',
        Queue     => 'General',
        AdminCc   => $group->PrincipalId,
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
    cmp_deeply($content->{AdminCc}, [{
        id   => $group_id,
        type => 'group',
        _url => re(qr{$rest_base_path/group/$group_id$}),
    }], 'group AdminCc');

    $payload = {
        AdminCc => 'admincc@example.com',
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    cmp_deeply($mech->json_response, [
        re(qr/Added admincc\@example.com as( a)? AdminCc for this ticket/),
        re(qr/Watcher Group is no longer( a)? AdminCc for this ticket/),
    ], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    }], 'one AdminCc user');

    $payload = {
        AdminCc => [$group_id, 'admincc@example.com'],
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    cmp_deeply($mech->json_response, [
        re(qr/Added Watcher Group as( a)? AdminCc for this ticket/),
    ], "updated ticket watchers");

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    cmp_deeply($content->{AdminCc}, [{
        type => 'user',
        id   => 'admincc@example.com',
        _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
    },
    {
        id   => $group_id,
        type => 'group',
        _url => re(qr{$rest_base_path/group/$group_id$}),
    }], 'AdminCc user and group');

    $res = $mech->get($content->{AdminCc}[1]{_url},
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
            id   => 'admincc@example.com',
            _url => re(qr{$rest_base_path/user/admincc\@example\.com$}),
        },
        {
            type => 'user',
            id   => 'admincc2@example.com',
            _url => re(qr{$rest_base_path/user/admincc2\@example\.com$}),
        }],
    }), 'fetched group');
}

done_testing;

