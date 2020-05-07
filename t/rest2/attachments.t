use strict;
use warnings;
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

done_testing;
