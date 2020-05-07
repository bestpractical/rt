use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

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

# search transactions for a specific ticket
my ($create_txn_url, $create_txn_id);
my ($comment_txn_url, $comment_txn_id);
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
    is($content->{count}, 5);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 5);
    is(scalar @{$content->{items}}, 5);

    my ($create, $priority1, $subject, $priority2, $comment) = @{ $content->{items} };

    is($create->{type}, 'transaction');
    is($priority1->{type}, 'transaction');
    is($subject->{type}, 'transaction');
    is($priority2->{type}, 'transaction');
    is($comment->{type}, 'transaction');

    $create_txn_url = $create->{_url};
    ok(($create_txn_id) = $create_txn_url =~ qr[/transaction/(\d+)]);

    $comment_txn_url = $comment->{_url};
    ok(($comment_txn_id) = $comment_txn_url =~ qr[/transaction/(\d+)]);
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

