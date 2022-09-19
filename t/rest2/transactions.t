use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;
my $test_queue = RT::Test->load_or_create_queue( Name => 'Test' );
my $link_ticket = RT::Test->create_ticket( Queue => 'Test', Subject => 'Link ticket' );

$user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
$user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
$user->PrincipalObj->GrantRight( Right => 'ShowTicketComments' );

my $ticket = RT::Ticket->new($user);
$ticket->Create(Queue => 'General', Subject => 'hello world');
ok($ticket->Id, 'got an id');
my ($ok, $msg) = $ticket->SetPriority(42);
ok($ok, $msg);
($ok, $msg) = $ticket->SetSubject('new subject');
ok($ok, $msg);
($ok, $msg) = $ticket->SetPriority(43);
ok($ok, $msg);
($ok, $msg) = $ticket->Comment(Content => "hello world", TimeTaken => 50);
ok($ok, $msg);
($ok, $msg) = $ticket->SetQueue($test_queue->Id);
ok($ok, $msg);
($ok, $msg) = $ticket->AddLink(Type => 'DependsOn', Target => $link_ticket->id);
ok($ok, $msg);
($ok, $msg) = $ticket->AddLink(Type => 'RefersTo', Target => 'https://external.example.com/23');
ok($ok, $msg);
($ok, $msg) = $ticket->DeleteLink(Type => 'DependsOn', Target => $link_ticket->id);
ok($ok, $msg);
($ok, $msg) = $ticket->DeleteLink(Type => 'RefersTo', Target => 'https://external.example.com/23');
ok($ok, $msg);

# search transactions for a specific ticket
my ($create_txn_url, $create_txn_id);
my ($comment_txn_url, $comment_txn_id);
my ($queue_txn_url, $queue_txn_id);
my ($add_link1_txn_url, $add_link1_txn_id, $add_link2_txn_url, $add_link2_txn_id);
my ($delete_link1_txn_url, $delete_link1_txn_id, $delete_link2_txn_url, $delete_link2_txn_id);

{
    my $res = $mech->post_json("$rest_base_path/transactions",
        [
            { field => 'ObjectType', value => 'RT::Ticket' },
            { field => 'ObjectId', value => $ticket->Id },
        ],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 10);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, undef, 'No total');
    is(scalar @{$content->{items}}, 10);

    my (
        $create, $priority1, $subject,   $priority2,    $comment,
        $queue,  $add_link1, $add_link2, $delete_link1, $delete_link2
    ) = @{ $content->{items} };


    is($create->{type}, 'transaction');
    is($priority1->{type}, 'transaction');
    is($subject->{type}, 'transaction');
    is($priority2->{type}, 'transaction');
    is($comment->{type}, 'transaction');

    $create_txn_url = $create->{_url};
    ok(($create_txn_id) = $create_txn_url =~ qr[/transaction/(\d+)]);

    $comment_txn_url = $comment->{_url};
    ok(($comment_txn_id) = $comment_txn_url =~ qr[/transaction/(\d+)]);

    $queue_txn_url = $queue->{_url};
    ok(($queue_txn_id) = $queue_txn_url =~ qr[/transaction/(\d+)]);

    $add_link1_txn_url = $add_link1->{_url};
    ok(($add_link1_txn_id) = $add_link1_txn_url =~ qr[/transaction/(\d+)]);
    $add_link2_txn_url = $add_link2->{_url};
    ok(($add_link2_txn_id) = $add_link2_txn_url =~ qr[/transaction/(\d+)]);

    $delete_link1_txn_url = $delete_link1->{_url};
    ok(($delete_link1_txn_id) = $delete_link1_txn_url =~ qr[/transaction/(\d+)]);
    $delete_link2_txn_url = $delete_link2->{_url};
    ok(($delete_link2_txn_id) = $delete_link2_txn_url =~ qr[/transaction/(\d+)]);
}

# search transactions for a specific ticket using TransactionSQL
{
    my $res = $mech->get("$rest_base_path/transactions?query=ObjectType='RT::Ticket' AND ObjectId=".$ticket->Id,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 10);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, undef, 'No total');
    is(scalar @{$content->{items}}, 10);

    my (
        $create, $priority1, $subject,   $priority2,    $comment,
        $queue,  $add_link1, $add_link2, $delete_link1, $delete_link2
    ) = @{ $content->{items} };


    is($create->{type}, 'transaction');
    is($priority1->{type}, 'transaction');
    is($subject->{type}, 'transaction');
    is($priority2->{type}, 'transaction');
    is($comment->{type}, 'transaction');
    is($queue->{type}, 'transaction');
    is($add_link1->{type}, 'transaction');
    is($add_link2->{type}, 'transaction');
    is($delete_link1->{type}, 'transaction');
    is($delete_link2->{type}, 'transaction');

    $create_txn_url = $create->{_url};
    ok(($create_txn_id) = $create_txn_url =~ qr[/transaction/(\d+)]);

    $comment_txn_url = $comment->{_url};
    ok(($comment_txn_id) = $comment_txn_url =~ qr[/transaction/(\d+)]);

    $queue_txn_url = $queue->{_url};
    ok(($queue_txn_id) = $queue_txn_url =~ qr[/transaction/(\d+)]);

    $add_link1_txn_url = $add_link1->{_url};
    ok(($add_link1_txn_id) = $add_link1_txn_url =~ qr[/transaction/(\d+)]);
    $add_link2_txn_url = $add_link2->{_url};
    ok(($add_link2_txn_id) = $add_link2_txn_url =~ qr[/transaction/(\d+)]);

    $delete_link1_txn_url = $delete_link1->{_url};
    ok(($delete_link1_txn_id) = $delete_link1_txn_url =~ qr[/transaction/(\d+)]);
    $delete_link2_txn_url = $delete_link2->{_url};
    ok(($delete_link2_txn_id) = $delete_link2_txn_url =~ qr[/transaction/(\d+)]);
}

# Transaction display
{
    my $res = $mech->get($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $create_txn_id);
    is($content->{Type}, 'Create');
    is($content->{TimeTaken}, 0);

    ok(exists $content->{$_}) for qw(Created);

    my $links = $content->{_hyperlinks};
    is(scalar(@$links), 1);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $create_txn_id);
    is($links->[0]{type}, 'transaction');
    is($links->[0]{_url}, $create_txn_url);

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $object = $content->{Object};
    is($object->{id}, $ticket->Id);
    is($object->{type}, 'ticket');
    like($object->{_url}, qr{$rest_base_path/ticket/@{[$ticket->Id]}$});

    $res = $mech->get($queue_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{id}, $queue_txn_id);
    is($content->{Type}, 'Set');
    is($content->{Field}, 'Queue');
    is($content->{OldValue}{id}, 1);
    is($content->{NewValue}{id}, $test_queue->Id);

    $res = $mech->get($add_link1_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{id}, $add_link1_txn_id);
    is($content->{Type}, 'AddLink');
    is($content->{Field}, 'DependsOn');
    is($content->{NewValue}{id}, $link_ticket->Id);

    $res = $mech->get($add_link2_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;

    is($content->{id}, $add_link2_txn_id);
    is($content->{Type}, 'AddLink');
    is($content->{Field}, 'RefersTo');
    is($content->{NewValue}, 'https://external.example.com/23');

    $res = $mech->get($delete_link1_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{id}, $delete_link1_txn_id);
    is($content->{Type}, 'DeleteLink');
    is($content->{Field}, 'DependsOn');
    is($content->{OldValue}{id}, $link_ticket->Id);

    $res = $mech->get($delete_link2_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{id}, $delete_link2_txn_id);
    is($content->{Type}, 'DeleteLink');
    is($content->{Field}, 'RefersTo');
    is($content->{OldValue}, 'https://external.example.com/23');
}

# (invalid) update
{
    my $res = $mech->put_json($create_txn_url,
        { Type => 'Set' },
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');

    $res = $mech->get($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Type}, 'Create');
}

# (invalid) delete
{
    my $res = $mech->delete($create_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');
}

# (invalid) create
{
    my $res = $mech->post_json("$rest_base_path/transaction",
        { Type => 'Create' },
        'Authorization' => $auth,
    );
    is($res->code, 405);
    is($mech->json_response->{message}, 'Method Not Allowed');
}

# Comment transaction
{
    my $res = $mech->get($comment_txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $comment_txn_id);
    is($content->{Type}, 'Comment');
    is($content->{TimeTaken}, 50);

    ok(exists $content->{$_}) for qw(Created);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $comment_txn_id);
    is($links->[0]{type}, 'transaction');
    is($links->[0]{_url}, $comment_txn_url);

    is($links->[1]{ref}, 'attachment');
    like($links->[1]{_url}, qr{$rest_base_path/attachment/\d+$});

    my $creator = $content->{Creator};
    is($creator->{id}, 'test');
    is($creator->{type}, 'user');
    like($creator->{_url}, qr{$rest_base_path/user/test$});

    my $object = $content->{Object};
    is($object->{id}, $ticket->Id);
    is($object->{type}, 'ticket');
    like($object->{_url}, qr{$rest_base_path/ticket/@{[$ticket->Id]}$});
}
done_testing;

