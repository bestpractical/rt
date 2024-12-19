use strict;
use warnings;

# Setting CorrespondAddress to make sure the From header of emails is set correctly
# Otherwise email parser would warn something about:
#     "Enoch Root via RT" <> is not a valid email address and is not user name

use RT::Test tests => undef, config => q{Set($CorrespondAddress, 'general@example.com');};
use MIME::Base64;

my ( $baseurl, $m ) = RT::Test->started_ok;

ok $m->login;

my $image_file = RT::Test::get_relocatable_file( 'bpslogo.png', '..', 'data' );
my $image_content;
{
    local $/;
    open my $fh, '<', $image_file;
    $image_content = <$fh>;
}

my $content = q{Test inline images: <img src="data:image/png;base64,} . encode_base64($image_content) . q{">};

diag "Testing inline images";
{
    $m->goto_create_ticket('General');
    $m->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject => 'Test inline images',
            Content => $content,
        },
        button => 'SubmitTicket'
    );

    my $ticket             = RT::Test->last_ticket;
    my $create_txn         = $ticket->Transactions->First;
    my $create_attachments = $create_txn->Attachments->ItemsArrayRef;
    is( @$create_attachments,                  3,                   'Found 3 attachments in create transaction' );
    is( $create_attachments->[0]->ContentType, 'multipart/related', 'First attachment is the multipart/related' );
    is( $create_attachments->[1]->ContentType, 'text/html',         'Second attachment is the html' );
    is( $create_attachments->[2]->ContentType, 'image/png',         'Third attachment is the image' );
    is( $create_attachments->[2]->Content,     $image_content,      'Image attachment content is correct' );

    my $dom       = $m->dom;
    my $image_url = 'Attachment/' . $create_txn->Id . '/' . $create_attachments->[2]->Id;
    ok( $dom->at(qq{img[src="$image_url"]}), 'Image displayed inline' );
    $m->text_contains('Image displayed inline above');

    my @mails = RT::Test->fetch_caught_mails;
    is( @mails, 1, 'Got 1 email' );
    my $entity = parse_mail( $mails[0] );
    is( $entity->mime_type, 'multipart/alternative', 'Email is multipart/alternative' );

    my @parts = $entity->parts;
    is( @parts,               2,                   'Got 2 parts' );
    is( $parts[0]->mime_type, 'text/plain',        'First part is text/plain' );
    is( $parts[1]->mime_type, 'multipart/related', 'Second part is multipart/related' );

    @parts = $parts[1]->parts;
    is( @parts,               2,           'Got 2 parts in multipart/related' );
    is( $parts[0]->mime_type, 'text/html', 'First part is text/html' );
    is( $parts[1]->mime_type, 'image/png', 'Second part is image/png' );
    my ($cid) = $parts[1]->head->get('Content-ID') =~ /<(.+)>/;
    like( $parts[0]->body_as_string, qr/img src="cid:\Q$cid\E"/, 'HTML content contains correct image src' );
    is( $parts[1]->bodyhandle->as_string, $image_content, 'Image content is correct' );
}

diag "Testing quoted images";
{

    my $dom = $m->dom;
    my $img = $dom->at(qq{img[src^="Attachment/"]});

    $m->follow_link_ok( { url_regex => qr/QuoteTransaction=/ }, 'Reply the create transaction' );
    $dom = $m->dom;
    my $textarea = $dom->at('textarea');
    like( $textarea->content, qr!<img loading="lazy" src="/Ticket/@{[$img->attr('src')]}!,
        'Quoted html contains converted image URL' );

    $m->submit_form(
        form_name => 'TicketUpdate',
        fields    => {
            UpdateCc => 'test@example.com',
        },
        button => 'SubmitTicket'
    );

    my $ticket = RT::Test->last_ticket;
    my $txns   = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    my $correspond_txn         = $txns->First;
    my $correspond_attachments = $correspond_txn->Attachments->ItemsArrayRef;
    is( @$correspond_attachments,                  3, 'Found 3 attachments in correspond transaction' );
    is( $correspond_attachments->[0]->ContentType, 'multipart/related', 'First attachment is the multipart/related' );
    is( $correspond_attachments->[1]->ContentType, 'text/html',         'Second attachment is the html' );
    is( $correspond_attachments->[2]->ContentType, 'image/png',         'Third attachment is the image' );
    is( $correspond_attachments->[2]->Content,     $image_content,      'Image attachment content is correct' );
    my $image_url = 'Attachment/' . $correspond_txn->Id . '/' . $correspond_attachments->[2]->Id;

    $dom = $m->dom;
    ok( $dom->at(qq{img[src="$image_url"]}), 'Image displayed inline' );
    $m->text_like( qr/(Image displayed inline above).*\1/s, 'Image displayed inline above' );

    my @mails = RT::Test->fetch_caught_mails;
    is( @mails, 1, 'Got 1 email' );
    my $entity = parse_mail( $mails[0] );
    is( $entity->mime_type, 'multipart/alternative', 'Email is multipart/alternative' );

    my @parts = $entity->parts;
    is( @parts,               2,                   'Got 2 parts' );
    is( $parts[0]->mime_type, 'text/plain',        'First part is text/plain' );
    is( $parts[1]->mime_type, 'multipart/related', 'Second part is multipart/related' );

    @parts = $parts[1]->parts;
    is( @parts,               2,           'Got 2 parts in multipart/related' );
    is( $parts[0]->mime_type, 'text/html', 'First part is text/html' );
    is( $parts[1]->mime_type, 'image/png', 'Second part is image/png' );
    my ($cid) = $parts[1]->head->get('Content-ID') =~ /<(.+)>/;
    like( $parts[0]->body_as_string, qr/img loading="lazy" src="cid:\Q$cid\E"/, 'HTML content contains correct image src' );
    is( $parts[1]->bodyhandle->as_string, $image_content, 'Image content is correct' );
}

done_testing();
