use strict;
use warnings;
use utf8;
use lib 't/lib';
use RT::Test::REST2 tests => undef;
use Test::Deep;
use MIME::Base64;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight(Right => 'CreateTicket');
$user->PrincipalObj->GrantRight(Right => 'ReplyToTicket');
$user->PrincipalObj->GrantRight(Right => 'CommentOnTicket');
$user->PrincipalObj->GrantRight(Right => 'ShowTicket');
$user->PrincipalObj->GrantRight(Right => 'ShowTicketComments');

my $ticket = RT::Ticket->new($user);
$ticket->Create(Queue => 'General', Subject => 'hello world');
my $ticket_id = $ticket->id;

my $image_name = 'image.png';
my $image_path = RT::Test::get_relocatable_file($image_name, 'data');
my $image_content;
open my $fh, '<', $image_path or die "Cannot read $image_path: $!\n";
{
    local $/;
    $image_content = <$fh>;
}
close $fh;

$image_content = MIME::Base64::encode_base64($image_content);

# Comment ticket with image and text attachments through JSON Base64
{
    my $payload = {
        Content     => 'Have you seen this <b>image</b>',
        ContentType => 'text/html',
        Subject     => 'HTML comment with PNG image and text file',
        Attachments => [
            {
                FileName => $image_name,
                FileType => 'image/png',
                FileContent => $image_content,
            },
            {
                FileName => 'password',
                FileType => 'text/plain',
                FileContent => MIME::Base64::encode_base64('Hey this is secret!'),
            },
        ],
    };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket_id/comment",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my $attachments = $ticket->Attachments->ItemsArrayRef;

    # 3 attachments + 1 wrapper
    is(scalar(@$attachments), 4);

    # 1st attachment is wrapper
    is($attachments->[0]->TransactionId, $transaction_id);
    is($attachments->[0]->Parent, 0);
    is($attachments->[0]->Subject, 'HTML comment with PNG image and text file');
    ok(!$attachments->[0]->Filename);
    is($attachments->[0]->ContentType, 'multipart/mixed');

    # 2nd attachment is comment's content
    is($attachments->[1]->Parent, $attachments->[0]->id);
    is($attachments->[1]->TransactionId, $transaction_id);
    is($attachments->[1]->ContentType, 'text/html');
    is($attachments->[1]->ContentEncoding, 'none');
    is($attachments->[1]->Content, 'Have you seen this <b>image</b>');
    ok(!$attachments->[1]->Subject);

    # 3rd attachment is image
    my $expected_encoding = $RT::Handle->BinarySafeBLOBs ? 'none' : 'base64';
    is($attachments->[2]->Parent, $attachments->[0]->id);
    is($attachments->[2]->TransactionId, $transaction_id);
    is($attachments->[2]->ContentType, 'image/png');
    is($attachments->[2]->ContentEncoding, $expected_encoding);
    is($attachments->[2]->Filename, $image_name);
    ok(!$attachments->[2]->Subject);

    # 4th attachment is text file
    is($attachments->[3]->Parent, $attachments->[0]->id);
    is($attachments->[3]->TransactionId, $transaction_id);
    is($attachments->[3]->ContentType, 'text/plain');
    is($attachments->[3]->ContentEncoding, 'none');
    is($attachments->[3]->Filename, 'password');
    is($attachments->[3]->Content, 'Hey this is secret!');
    ok(!$attachments->[3]->Subject);
}

# Check the GET /ticket/:id/attachments endpoint
{
    my $res = $mech->get(
        "$rest_base_path/ticket/$ticket_id/attachments?fields=Subject,Filename,ContentType,ContentLength",
        'Authorization' => $auth
    );
    is( $res->code, 200 );

    cmp_deeply(
        $mech->json_response,
        {   per_page => 20,
            pages    => undef,
            total    => undef,
            page     => 1,
            count    => 4,
            items    => [
                {   type    => 'attachment',
                    Subject => 'HTML comment with PNG image and text file',
                    _url    => re(qr/^https?:/),
                    ContentType   => 'multipart/mixed',
                    ContentLength => 0,
                    Filename      => '',
                    id            => re(qr/^\d+$/)
                },
                {   type          => 'attachment',
                    Subject       => '',
                    _url          => re(qr/^https?:/),
                    ContentType   => 'text/html',
                    ContentLength => 31,
                    Filename      => '',
                    id            => re(qr/^\d+$/)
                },
                {   type          => 'attachment',
                    Subject       => '',
                    _url          => re(qr/^https?:/),
                    ContentType   => 'image/png',
                    ContentLength => 3929,
                    Filename      => 'image.png',
                    id            => re(qr/^\d+$/)
                },
                {   type          => 'attachment',
                    Subject       => '',
                    _url          => re(qr/^https?:/),
                    ContentType   => 'text/plain',
                    ContentLength => 19,
                    Filename      => 'password',
                    id            => re(qr/^\d+$/)
                },
            ]
        },
        'Got expected attachment list'
    );
}

# Comment ticket with image attachment and no content through JSON Base64
{
    my $payload = {
        Subject     => 'No content, just an image',
        Attachments => [
            {
                FileName => $image_name,
                FileType => 'image/png',
                FileContent => $image_content,
            },
        ],
    };
    my $res = $mech->post_json("$rest_base_path/ticket/$ticket_id/comment",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my @attachments = grep { $_->TransactionId == $transaction_id } @{$ticket->Attachments->ItemsArrayRef};

    # 2 attachments + 1 wrapper
    is(scalar(@attachments), 3);

    # 1st attachment is wrapper
    is($attachments[0]->Parent, 0);
    is($attachments[0]->Subject, 'No content, just an image');
    ok(!$attachments[0]->Filename);
    is($attachments[0]->ContentType, 'multipart/mixed');

    # 2nd attachment is empty comment's content
    is($attachments[1]->Parent, $attachments[0]->id);
    is($attachments[1]->TransactionId, $transaction_id);
    is($attachments[1]->ContentType, 'application/octet-stream');
    ok(!$attachments[1]->ContentEncoding);
    ok(!$attachments[1]->Content);
    ok(!$attachments[1]->Subject);

    # 3rd attachment is image
    my $expected_encoding = $RT::Handle->BinarySafeBLOBs ? 'none' : 'base64';
    is($attachments[2]->Parent, $attachments[0]->id);
    is($attachments[2]->TransactionId, $transaction_id);
    is($attachments[2]->ContentType, 'image/png');
    is($attachments[2]->ContentEncoding, $expected_encoding);
    is($attachments[2]->Filename, $image_name);
    ok(!$attachments[2]->Subject);
}

my $json = JSON->new->utf8;

# Comment ticket with image and text attachments through multipart/form-data
{
    my $payload = {
        Content     => 'Have you seen this <b>image</b>',
        ContentType => 'text/html',
        Subject     => 'HTML comment with PNG image and text file',
    };

    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
    my $res = $mech->post("$rest_base_path/ticket/$ticket_id/comment",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'        => $json->encode($payload),
            'Attachments' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
            'Attachments' => [undef, 'password', 'Content-Type' => 'text/plain', Content => 'Hey this is secret!']]);

    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my @attachments = grep { $_->TransactionId == $transaction_id } @{$ticket->Attachments->ItemsArrayRef};

    # 3 attachments + 1 wrapper
    is(scalar(@attachments), 4);

    # 1st attachment is wrapper
    is($attachments[0]->TransactionId, $transaction_id);
    is($attachments[0]->Parent, 0);
    is($attachments[0]->Subject, 'HTML comment with PNG image and text file');
    ok(!$attachments[0]->Filename);
    is($attachments[0]->ContentType, 'multipart/mixed');

    # 2nd attachment is comment's content
    is($attachments[1]->Parent, $attachments[0]->id);
    is($attachments[1]->TransactionId, $transaction_id);
    is($attachments[1]->ContentType, 'text/html');
    is($attachments[1]->ContentEncoding, 'none');
    is($attachments[1]->Content, 'Have you seen this <b>image</b>');
    ok(!$attachments[1]->Subject);

    # 3rd attachment is image
    my $expected_encoding = $RT::Handle->BinarySafeBLOBs ? 'none' : 'base64';
    is($attachments[2]->Parent, $attachments[0]->id);
    is($attachments[2]->TransactionId, $transaction_id);
    is($attachments[2]->ContentType, 'image/png');
    is($attachments[2]->ContentEncoding, $expected_encoding);
    is($attachments[2]->Filename, $image_name);
    ok(!$attachments[2]->Subject);

    # 4th attachment is text file
    is($attachments[3]->Parent, $attachments[0]->id);
    is($attachments[3]->TransactionId, $transaction_id);
    is($attachments[3]->ContentType, 'text/plain');
    is($attachments[3]->ContentEncoding, 'none');
    is($attachments[3]->Filename, 'password');
    is($attachments[3]->Content, 'Hey this is secret!');
    ok(!$attachments[3]->Subject);
}

# Comment ticket with image attachment and no content through multipart/form-data
{
    my $payload = {
        Subject     => 'No content, just an image',
    };

    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
    my $res = $mech->post("$rest_base_path/ticket/$ticket_id/comment",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'        => $json->encode($payload),
            'Attachments' => [$image_path, $image_name, 'Content-Type' => 'image/png']]);

    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my @attachments = grep { $_->TransactionId == $transaction_id } @{$ticket->Attachments->ItemsArrayRef};

    # 2 attachments + 1 wrapper
    is(scalar(@attachments), 3);

    # 1st attachment is wrapper
    is($attachments[0]->Parent, 0);
    is($attachments[0]->Subject, 'No content, just an image');
    ok(!$attachments[0]->Filename);
    is($attachments[0]->ContentType, 'multipart/mixed');

    # 2nd attachment is empty comment's content
    is($attachments[1]->Parent, $attachments[0]->id);
    is($attachments[1]->TransactionId, $transaction_id);
    is($attachments[1]->ContentType, 'application/octet-stream');
    ok(!$attachments[1]->ContentEncoding);
    ok(!$attachments[1]->Content);
    ok(!$attachments[1]->Subject);

    # 3rd attachment is image
    my $expected_encoding = $RT::Handle->BinarySafeBLOBs ? 'none' : 'base64';
    is($attachments[2]->Parent, $attachments[0]->id);
    is($attachments[2]->TransactionId, $transaction_id);
    is($attachments[2]->ContentType, 'image/png');
    is($attachments[2]->ContentEncoding, $expected_encoding);
    is($attachments[2]->Filename, $image_name);
    ok(!$attachments[2]->Subject);
}

my $utf8_image_name = "λογότυπο.png";

# Comment ticket with non-ASCII attachment filename through JSON Base64
{
    my $payload = {
        Content     => 'Image with a non-ASCII filename',
        ContentType => 'text/plain',
        Attachments => [
            {   FileName    => $utf8_image_name,
                FileType    => 'image/png',
                FileContent => $image_content,
            },
        ],
    };

    my $res = $mech->post_json("$rest_base_path/ticket/$ticket_id/comment",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my @attachments = grep { $_->TransactionId == $transaction_id } @{$ticket->Attachments->ItemsArrayRef};
    is(scalar(@attachments), 3, 'Wrapper, content, and image attachments');
    is($attachments[2]->ContentType, 'image/png');
    is($attachments[2]->Filename, $utf8_image_name, 'Image attachment has the non-ASCII filename');
}

# Comment ticket with non-ASCII attachment filename through multipart/form-data
{
    my $payload = {
        Content     => 'Image with a non-ASCII filename',
        ContentType => 'text/plain',
    };

    my $res = $mech->post("$rest_base_path/ticket/$ticket_id/comment",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'        => $json->encode($payload),
            'Attachments' => [
                $image_path,
                Encode::encode('UTF-8', $utf8_image_name),
                'Content-Type' => 'image/png',
            ],
        ]
    );

    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/)]);

    my $transaction_id = $ticket->Transactions->Last->id;
    my @attachments = grep { $_->TransactionId == $transaction_id } @{$ticket->Attachments->ItemsArrayRef};
    is(scalar(@attachments), 3, 'Wrapper, content, and image attachments');
    is($attachments[2]->ContentType, 'image/png');
    is($attachments[2]->Filename, $utf8_image_name, 'Image attachment has the non-ASCII filename');
}

# Create ticket with non-ASCII attachment filename through JSON Base64
{
    my $payload = {
        Queue       => 'General',
        Subject     => 'Ticket with a non-ASCII attachment filename',
        Content     => 'Image with a non-ASCII filename',
        ContentType => 'text/plain',
        Attachments => [
            {   FileName    => $utf8_image_name,
                FileType    => 'image/png',
                FileContent => $image_content,
            },
        ],
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    my ($new_ticket_id) = $res->header('location') =~ qr[/ticket/(\d+)];
    ok($new_ticket_id, 'Created ticket');

    my $new_ticket = RT::Ticket->new($user);
    $new_ticket->Load($new_ticket_id);
    my ($image) = grep { $_->ContentType eq 'image/png' } @{$new_ticket->Attachments->ItemsArrayRef};
    ok($image, 'Ticket has an image attachment');
    is($image->Filename, $utf8_image_name, 'Image attachment has the non-ASCII filename');
}

done_testing;
