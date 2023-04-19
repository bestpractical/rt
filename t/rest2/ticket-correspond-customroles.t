use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;
use MIME::Base64;

BEGIN {
    plan skip_all => 'RT 4.4 required'
        unless RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
}

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

# Set up a couple of custom roles
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

$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket ShowTicket ModifyTicket OwnTicket AdminUsers SeeGroup SeeQueue/;

# Ticket Creation
my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Ticket Display
{
    $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;

    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');

    ok( exists $content->{$_}, "Content exists for $_" ) for qw(AdminCc TimeEstimated Started Cc
        LastUpdated TimeWorked Resolved Created Due Priority EffectiveId CustomRoles);

    # Remove this in RT 5.2
    ok( exists $content->{$_}, "Content exists for $_" ) for 'Single Member', 'Multi Member';

}

diag "Correspond with custom roles";
{
    $user->PrincipalObj->GrantRight( Right => 'ReplyToTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'correspond' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got correspond hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);

    my $correspond_url = $mech->url_for_hypermedia('correspond');
    my $comment_url = $correspond_url;
    $comment_url =~ s/correspond/comment/;

    $res = $mech->post_json($correspond_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Single Member' => 'foo@bar.example',
                'Multi Member' => 'quux@cabbage.example',
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);
    $content = $mech->json_response;

    # Because CustomRoles are set in an unpredictable order, sort the
    # responses so we have a predictable order.
    @$content = sort { $a cmp $b } (@$content);
    cmp_deeply($content, ['Added quux@cabbage.example as Multi Member for this ticket', re(qr/Correspondence added|Message recorded/), 'Single Member changed from Nobody to foo@bar.example']);
    like($res->header('Location'), qr{$rest_base_path/transaction/\d+$});
    $res = $mech->get($res->header('Location'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Type}, 'Correspond');
    is($content->{TimeTaken}, 0);
    is($content->{Object}{type}, 'ticket');
    is($content->{Object}{id}, $ticket_id);

    $res = $mech->get($mech->url_for_hypermedia('attachment'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Content}, encode_base64('Hello from hypermedia!'));
    is($content->{ContentType}, 'text/plain');

    # Load the ticket and check the custom roles
    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);

    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'foo@bar.example',
       "Single Member role set correctly");
    is($ticket->RoleAddresses("RT::CustomRole-$multi_id"), 'quux@cabbage.example',
       "Multi Member role set correctly");
}

diag "Comment with custom roles";
{
    $user->PrincipalObj->GrantRight( Right => 'CommentOnTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'comment' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got comment hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);

    my $comment_url = $mech->url_for_hypermedia('comment');

    $res = $mech->post_json($comment_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Single Member' => 'foo-new@bar.example',
                'Multi Member' => 'quux-new@cabbage.example',
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);

    # Load the ticket and check the custom roles
    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);

    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'foo-new@bar.example',
       "Single Member role set correctly");
    is($ticket->RoleAddresses("RT::CustomRole-$multi_id"), 'quux-new@cabbage.example',
       "Multi Member role updated correctly");

    # Supply an array for multi-member role
    $res = $mech->post_json($comment_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Multi Member' => ['abacus@example.com', 'quux-new@cabbage.example'],
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);

    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'foo-new@bar.example',
       "Single Member role unchanged");
    is($ticket->RoleAddresses("RT::CustomRole-$multi_id"), 'abacus@example.com, quux-new@cabbage.example',
       "Multi Member role set correctly");

    # Add an existing user to multi-member role
    $res = $mech->post_json($comment_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Multi Member' => 'abacus@example.com',
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);

    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'foo-new@bar.example',
       "Single Member role unchanged");
    is($ticket->RoleAddresses("RT::CustomRole-$multi_id"), 'abacus@example.com',
       "Multi Member role unchanged");

    # Supply an array for single-member role
    $res = $mech->post_json($comment_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Single Member' => ['abacus@example.com', 'quux-new@cabbage.example'],
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);
    $content = $mech->json_response;
    cmp_deeply($content, ['Comments added', 'Single Member changed from foo-new@bar.example to abacus@example.com'], "Got expected respose");
    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'abacus@example.com',
       "Single Member role changed to first member of array");

    # Try using a username instead of password
    $res = $mech->post_json($comment_url,
        {
            Content => 'Hello from hypermedia!',
            ContentType => 'text/plain',
            CustomRoles => {
                'Single Member' => 'test',
            },
        },
        'Authorization' => $auth,
    );
    is($res->code, 201);
    $content = $mech->json_response;
    cmp_deeply($content, ['Comments added', 'Single Member changed from abacus@example.com to test'], "Got expected respose");
    is($ticket->RoleAddresses("RT::CustomRole-$single_id"), 'test@rt.example',
       "Single Member role changed");
}

done_testing;
