use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;
use MIME::Base64;

use Encode qw(decode encode);

# Test using integer priorities
RT->Config->Set(EnablePriorityAsString => 0);
my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

# Empty DB
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($mech->json_response->{count}, 0);
}

# Missing Queue
{
    my $res = $mech->post_json("$rest_base_path/ticket",
        {
            Subject => 'Ticket creation using REST',
        },
        'Authorization' => $auth,
    );
    is($res->code, 400);
    is($mech->json_response->{message}, 'Could not create ticket. Queue not set');
}

# Ticket Creation
my ($ticket_url, $ticket_id);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
    };

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);
}

# Ticket Display
{
    # Rights Test - No ShowTicket
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowTicket
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

    ok(exists $content->{$_}) for qw(AdminCc TimeEstimated Started Cc
                                     LastUpdated TimeWorked Resolved
                                     Created Due Priority EffectiveId);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'ticket');
    like($links->[0]{_url}, qr[$rest_base_path/ticket/$ticket_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/ticket/$ticket_id/history$]);

    my $queue = $content->{Queue};
    is($queue->{id}, 1);
    is($queue->{type}, 'queue');
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
    ok(!exists $queue->{Name}, 'queue name is absent');
    ok(!exists $queue->{Lifecycle}, 'queue lifecycle is absent');

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

# Ticket display with additional fields
{
    my $res = $mech->get($ticket_url . '?fields[Queue]=Name,Lifecycle',
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);

    my $queue = $content->{Queue};
    is($queue->{id},   1);
    is($queue->{type}, 'queue');
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
    is($queue->{Name},      '', 'empty queue name');
    is($queue->{Lifecycle}, '', 'empty queue lifecycle');

    $user->PrincipalObj->GrantRight(Right => 'SeeQueue');

    $res = $mech->get($ticket_url . '?fields[Queue]=Name,Lifecycle',
        'Authorization' => $auth,);
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{id}, $ticket_id);

    $queue = $content->{Queue};
    is($queue->{id},   1);
    is($queue->{type}, 'queue');
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
    is($queue->{Name},      'General', 'queue name');
    is($queue->{Lifecycle}, 'default', 'queue lifecycle');

    $user->PrincipalObj->RevokeRight(Right => 'SeeQueue');
}

# Ticket Create Attachment created correctly
{
    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $transaction_id = $ticket->Transactions->Last->id;
    my $attachments = $ticket->Attachments->ItemsArrayRef;

    # 1 attachment
    is(scalar(@$attachments), 1);

    is($attachments->[0]->Parent, 0);
    is($attachments->[0]->Subject, 'Ticket creation using REST');
    ok(!$attachments->[0]->Filename);
    is($attachments->[0]->ContentType, 'text/plain');
}

# Ticket Search
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{pages}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $ticket = $content->{items}->[0];
    is($ticket->{type}, 'ticket');
    is($ticket->{id}, 1);
    like($ticket->{_url}, qr{$rest_base_path/ticket/1$});
    is(scalar keys %$ticket, 3);
}

# Ticket Search - Fields
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0&fields=Status,Subject",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $ticket = $content->{items}->[0];
    is($ticket->{Subject}, 'Ticket creation using REST');
    is($ticket->{Status}, 'new');
    is(scalar keys %$ticket, 5);
}

# Ticket Search - Fields, sub objects, no right to see Queues
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0&fields=Status,Owner,Queue&fields[Queue]=Name,Description&fields[Owner]=Name",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $ticket = $content->{items}->[0];

    is($ticket->{Status}, 'new');
    is($ticket->{Queue}{Name}, '');
    is($ticket->{Queue}{id}, '1');
    is($ticket->{Queue}{type}, 'queue');
    like($ticket->{Queue}{_url}, qr[$rest_base_path/queue/1$]);
    is($ticket->{Owner}{Name}, 'Nobody');
    is(scalar keys %$ticket, 6);
}

# Ticket Search - Fields, sub objects with SeeQueue right
{
    $user->PrincipalObj->GrantRight( Right => 'SeeQueue' );

    my $res = $mech->get("$rest_base_path/tickets?query=id>0&fields=Status,Owner,Queue&fields[Queue]=Name,Description&fields[Owner]=Name",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 1);

    my $ticket = $content->{items}->[0];

    is($ticket->{Status}, 'new');
    is($ticket->{Queue}{Name}, 'General');
    is($ticket->{Queue}{Description}, 'The default queue');
    is($ticket->{Queue}{id}, '1');
    is($ticket->{Queue}{type}, 'queue');
    like($ticket->{Queue}{_url}, qr[$rest_base_path/queue/1$]);
    is($ticket->{Owner}{Name}, 'Nobody');
    is(scalar keys %$ticket, 6);
}

# Ticket Update
{
    my $payload = {
        Subject  => 'Ticket update using REST',
        Priority => 42,
    };

    # Rights Test - No ModifyTicket
    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Ticket 1: Permission Denied', 'Ticket 1: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from (no value) to '42'", "Ticket 1: Subject changed from 'Ticket creation using REST' to 'Ticket update using REST'"]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);

    # now that we have ModifyTicket, we should have additional hypermedia
    my $links = $content->{_hyperlinks};
    is(scalar @$links, 5);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, 1);
    is($links->[0]{type}, 'ticket');
    like($links->[0]{_url}, qr[$rest_base_path/ticket/$ticket_id$]);

    is($links->[1]{ref}, 'history');
    like($links->[1]{_url}, qr[$rest_base_path/ticket/$ticket_id/history$]);

    is($links->[2]{ref}, 'lifecycle');
    like($links->[2]{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);
    is($links->[2]{label}, 'Open It');
    is($links->[2]{update}, 'Respond');
    is($links->[2]{from}, 'new');
    is($links->[2]{to}, 'open');

    is($links->[3]{ref}, 'lifecycle');
    like($links->[3]{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);
    is($links->[3]{label}, 'Resolve');
    is($links->[3]{update}, 'Comment');
    is($links->[3]{from}, 'new');
    is($links->[3]{to}, 'resolved');

    is($links->[4]{ref}, 'lifecycle');
    like($links->[4]{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);
    is($links->[4]{label}, 'Reject');
    is($links->[4]{update}, 'Respond');
    is($links->[4]{from}, 'new');
    is($links->[4]{to}, 'rejected');

    # update again with no changes
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, []);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);
}

# Transactions
{
    my $res = $mech->get($ticket_url,
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

# Ticket Reply
{
    # we know from earlier tests that look at hypermedia without ReplyToTicket
    # that correspond wasn't available, so we don't need to check again here

    $user->PrincipalObj->GrantRight( Right => 'ReplyToTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'correspond' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got correspond hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/correspond$]);

    $res = $mech->post($mech->url_for_hypermedia('correspond'),
        'Authorization' => $auth,
        'Content-Type' => 'text/plain',
        'Content' => 'Hello from hypermedia!',
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Correspondence added|Message recorded/)]);

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
}

# Ticket Comment
{
    my $payload = {
        Content     => "<i>(hello secret camera \x{5e9}\x{5dc}\x{5d5}\x{5dd})</i>",
        ContentType => 'text/html',
        Subject     => 'shh',
        TimeTaken   => 129,
    };

    # we know from earlier tests that look at hypermedia without ReplyToTicket
    # that correspond wasn't available, so we don't need to check again here

    $user->PrincipalObj->GrantRight( Right => 'CommentOnTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'comment' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got comment hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);

    $res = $mech->post_json($mech->url_for_hypermedia('comment'),
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $txn_url = $res->header('Location');
    like($txn_url, qr{$rest_base_path/transaction/\d+$});
    $res = $mech->get($txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    $user->PrincipalObj->GrantRight( Right => 'ShowTicketComments' );

    $res = $mech->get($txn_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Type}, 'Comment');
    is($content->{TimeTaken}, 129);
    is($content->{Object}{type}, 'ticket');
    is($content->{Object}{id}, $ticket_id);

    $res = $mech->get($mech->url_for_hypermedia('attachment'),
        'Authorization' => $auth,
    );
    is($res->code, 200);
    $content = $mech->json_response;
    is($content->{Subject}, 'shh');

    # Note below: D7 A9 is the UTF-8 encoding of U+5E9, etc.
    is($content->{Content}, encode_base64("<i>(hello secret camera \xD7\xA9\xD7\x9C\xD7\x95\xD7\x9D)</i>"));
    is($content->{ContentType}, 'text/html');
}

# Ticket Sorted Search
{
    my $ticket2 = RT::Ticket->new($RT::SystemUser);
    ok(my ($ticket2_id) = $ticket2->Create(Queue => 'General', Subject => 'Ticket for test'));
    my $ticket3 = RT::Ticket->new($RT::SystemUser);
    ok(my ($ticket3_id) = $ticket3->Create(Queue => 'General', Subject => 'Ticket for test'));
    my $ticket4 = RT::Ticket->new($RT::SystemUser);
    ok(my ($ticket4_id) = $ticket4->Create(Queue => 'General', Subject => 'Ticket to test sorted search'));

    my $res = $mech->get("$rest_base_path/tickets?query=Subject LIKE 'test'&orderby=Subject&order=DESC&orderby=id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    my $first_ticket = $content->{items}->[0];
    is($first_ticket->{type}, 'ticket');
    is($first_ticket->{id}, $ticket4_id);
    like($first_ticket->{_url}, qr{$rest_base_path/ticket/$ticket4_id$});

    my $second_ticket = $content->{items}->[1];
    is($second_ticket->{type}, 'ticket');
    is($second_ticket->{id}, $ticket2_id);
    like($second_ticket->{_url}, qr{$rest_base_path/ticket/$ticket2_id$});

    my $third_ticket = $content->{items}->[2];
    is($third_ticket->{type}, 'ticket');
    is($third_ticket->{id}, $ticket3_id);
    like($third_ticket->{_url}, qr{$rest_base_path/ticket/$ticket3_id$});
}

# Ticket Creation - with attachments
{
    my $payload = {
        Subject => 'Ticket creation using REST, with attachments.',
        Queue   => 'General',
        Content => 'Testing ticket creation with attachments using REST API.',
        Attachments => [
            {   FileName    => 'plain.txt',
                FileType    => 'text/plain',
                FileContent => MIME::Base64::encode_base64('Hello, World!')
            },
            {   FileName    => 'html.htm',
                FileType    => 'text/html',
                FileContent => MIME::Base64::encode_base64(
                    encode( 'UTF-8', "<p><i>Easy</i> as \x{03c0}</p>" )
                ),
            },
            {   FileName => 'moon.png',
                FileType => 'image/png',
                FileContent =>
                    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAGQAAABkABchkaRQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAADfSURBVDiNndM9TsNAFATgzy5yjZSAE85JBygETgENUPF3iBCitHAFQkcIhZ/Ryn9gRlrZmp2Z3ef3TBOHOMULPrDBMrhpi/4HI5xjix2+4nmJRbx/Yh7ahvkpRPVV4QDXwT3UQy46zGkAZDgK/iytefvHgCrkJsqZUH6cLnNbABSxd5Jhhf1IbkMXv8Qux7hH1Ic1xvk/jBWy6gavumvtwx7ectwZXkKh7MA95XgObeOtpI2U4zl0kGbpxgiPvwQUcXLrKFchc82f6Ur0PK49azOnmOI4TBu84zm4SV38DeIVYkrYJyNbAAAAAElFTkSuQmCC'
            },
        ]
    };

    my $res = $mech->post_json( "$rest_base_path/ticket", $payload,
        'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( $ticket_url = $res->header('location') );
    ok( ($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)] );
}

# We have the attachments added above
{
    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $transaction_id = $ticket->Transactions->Last->id;
    my $attachments    = $ticket->Attachments->ItemsArrayRef;

    # The 5 attachments are:
    # 1) Top-level multipart
    # 2) Top-level ticket content
    # 3-5) The three attachments added in the Attachments array
    is( scalar(@$attachments), 5 );

    is( $attachments->[0]->ContentType, 'multipart/mixed' );

    is( $attachments->[1]->ContentType, 'text/plain' );
    is( $attachments->[1]->Content,
        'Testing ticket creation with attachments using REST API.' );

    is( $attachments->[2]->ContentType, 'text/plain' );
    is( $attachments->[2]->Filename,    'plain.txt' );
    is( $attachments->[2]->Content,     'Hello, World!' );

    is( $attachments->[3]->ContentType, 'text/html' );
    is( $attachments->[3]->Filename,    'html.htm' );
    is( $attachments->[3]->Content,     "<p><i>Easy</i> as \x{03c0}</p>" );

    is( $attachments->[4]->ContentType, 'image/png' );
    is( $attachments->[4]->Filename,    'moon.png' );
    like( $attachments->[4]->Content, qr/IHDR/, "Looks like a PNG image" );
}

# Ticket Creation - with attachments, using multipart/form-data
my $json = JSON->new->utf8;
{
    my $plain_name = 'plain.txt';
    my $plain_path = RT::Test::get_relocatable_file($plain_name, 'data');
    my $html_name  = 'html.htm';
    my $html_path  = RT::Test::get_relocatable_file($html_name, 'data');
    my $img_name   = 'image.png';
    my $img_path   = RT::Test::get_relocatable_file($img_name, 'data');

    my $payload = {
        Subject => 'Ticket creation using REST, multipart/form-data, with attachments.',
        Queue   => 'General',
        Content => 'Testing ticket creation, multipart/form-data, with attachments using REST API.',
    };

    my $res = $mech->post( "$rest_base_path/ticket", $payload,
                           'Authorization' => $auth,
                           'Content_Type' => 'form-data',
                           'Content' => [
                               'JSON' => $json->encode($payload),
                               'Attachments' => [$plain_path, $plain_name, 'text/plain'],
                               'Attachments' => [$html_path,  $html_name,  'text/html' ],
                               'Attachments' => [$img_path,   $img_name,   'image/png' ]
                           ]);
    is( $res->code, 201 );
    ok( $ticket_url = $res->header('location') );
    ok( ($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)] );
}

# Validate that the ticket was created correctly

{
    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $transaction_id = $ticket->Transactions->Last->id;
    my $attachments    = $ticket->Attachments->ItemsArrayRef;

    # The 5 attachments are:
    # 1) Top-level multipart
    # 2) Top-level ticket content
    # 3-5) The three attachments added in the Attachments array
    is( scalar(@$attachments), 5 );

    is( $attachments->[0]->ContentType, 'multipart/mixed' );

    is( $attachments->[1]->ContentType, 'text/plain' );
    is( $attachments->[1]->Content,
        'Testing ticket creation, multipart/form-data, with attachments using REST API.' );

    is( $attachments->[2]->ContentType, 'text/plain' );
    is( $attachments->[2]->Filename,    'plain.txt' );
    is( $attachments->[2]->Content,     "Hello, World!\n" );

    is( $attachments->[3]->ContentType, 'text/html' );
    is( $attachments->[3]->Filename,    'html.htm' );
    is( $attachments->[3]->Content,     "<p><i>Easy</i> as \x{03c0}</p>\n" );

    is( $attachments->[4]->ContentType, 'image/png' );
    is( $attachments->[4]->Filename,    'image.png' );
    like( $attachments->[4]->Content, qr/IHDR/, "Looks like a PNG image" );
}

# Ticket Creation - with custom field uploads, using multipart/form-data
{
    my $image_cf = RT::Test->load_or_create_custom_field( Name => 'Image', Queue => 'General', Type => 'Image' );
    $user->PrincipalObj->GrantRight( Right => $_ ) for qw/SeeCustomField ModifyCustomField/;

    my $img_name = 'image.png';
    my $img_path = RT::Test::get_relocatable_file( $img_name, 'data' );
    my $img_content = do {
        local $/;
        open my $fh, '<', $img_path or die $!;
        <$fh>;
    };

    my $payload  = {
        Subject      => 'Ticket creation using REST, multipart/form-data, with custom field uploads',
        Queue        => 'General',
        Content      => 'Testing ticket creation, multipart/form-data, with custom field uploads using REST API.',
        CustomFields => { Image => { UploadField => 'image' } },
    };

    my $res = $mech->post(
        "$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'image' => [ $img_path, $img_name, 'image/png' ],
        ],
    );
    is( $res->code, 201 );
    ok( $ticket_url = $res->header('location') );
    ok( ($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)] );

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $value = $ticket->CustomFieldValues( $image_cf )->First;
    is( $value->Content, 'image.png', 'image file name');
    is( $value->LargeContent, $img_content, 'image file content');
}

done_testing;
