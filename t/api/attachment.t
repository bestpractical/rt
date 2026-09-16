
use strict;
use warnings;
use RT;
use RT::Test tests => undef;


{

ok (require RT::Attachment);


}

{

my $test1 = "From: jesse";
my @headers = RT::Attachment->_SplitHeaders($test1);
is ($#headers, 0, $test1 );

my $test2 = qq{From: jesse
To: bobby
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test2);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


my $test3 = qq{From: jesse
To: bobby,
 Suzie,
    Sally,
    Joey: bizzy,
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test3);
is ($#headers, 2, "testing a bunch of singline multiple headers" );



}


{
    my $iso_8859_1_ticket_email =
      RT::Test::get_relocatable_file( 'new-ticket-from-iso-8859-1',
        ( File::Spec->updir(), 'data', 'emails' ) );
    my $content = RT::Test->file_content($iso_8859_1_ticket_email);

    my $parser = RT::EmailParser->new;
    $parser->ParseMIMEEntityFromScalar($content);
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    my ( $id, $msg ) =
      $attachment->Create( TransactionId => 1, Attachment => $parser->Entity );
    ok( $id, $msg );
    my $mime = $attachment->ContentAsMIME;
    like( $mime->head->get('Content-Type'),
        qr/charset="iso-8859-1"/, 'content type of ContentAsMIME is original' );
    is(
        Encode::decode( 'iso-8859-1', $mime->stringify_body ),
        Encode::decode( 'UTF-8',      "Håvard\n" ),
        'body of ContentAsMIME is original'
    );
}

diag 'Test clearing and replacing header and content in attachments table';
{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue';

    my $t = RT::Test->create_ticket( Queue => 'General', Subject => 'test' );
    ok $t && $t->id, 'created a ticket';

    $t->Comment( Content => 'test' );

    my $attachments = RT::Attachments->new(RT->SystemUser);
    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'test',
    );
    is $attachments->Count, 1, 'Found content with "test"';

    # Replace attachment value for 'test' in Conetent col
    my ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'test', Replacement => 'new_value', Headers => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'test',
    );
    is $attachments->Count, 0, 'Found no content with "test"';

    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'new_value',
    );
    is $attachments->Count, 1, 'Found content with "new_value"';

    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'API',
    );
    is $attachments->Count, 1, 'Found header with content "API"';

    # Replace attachment value for 'API' in Header col
    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'API', Replacement => 'replacement', Content => 0);
    ok $ret, $msg;
    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'API',
    );
    is $attachments->Count, 0, 'Found no header with content "API"';
    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'replacement',
    );
    is $attachments->Count, 1, 'Found header with content "replacement"';

    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'new_value', Replacement => 'replacement', Content => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;
    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'new_value',
    );
    is $attachments->Count, 1, 'Content is not changed when flagged as false';

    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'replacement', Replacement => 'new_value', Headers => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;
    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'replacement',
    );
    is $attachments->Count, 1, 'Headers are not replaced when flagged as false';
}

diag 'Test clearing and replacing header and content in attachments from example emails';
{
    my $email_file =
      RT::Test::get_relocatable_file( 'multipart-alternative-with-umlaut',
        ( File::Spec->updir(), 'data', 'emails' ) );
    my $content = RT::Test->file_content($email_file);

    my $parser = RT::EmailParser->new;
    $parser->ParseMIMEEntityFromScalar($content);
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test munge', MIMEObj => $parser->Entity );
    my $decoded_umlaut = Encode::decode( 'UTF-8', 'Grüßen' );

    my $attachments = $ticket->Attachments( WithHeaders => 1, WithContent => 1 );
    while ( my $att = $attachments->Next ) {
        if ( $att->Content ) {
            like( $att->Content, qr/$decoded_umlaut/, "Content contains $decoded_umlaut" );
            unlike( $att->Content, qr/anonymous/, 'Content lacks anonymous' );
        }
        else {
            like( $att->Headers, qr/"Stever, Gregor" <gst\@example.com>/, 'Headers contain gst@example.com' );
            unlike( $att->Headers, qr/anon\@example.com/, 'Headers lack anon@example.com' );
        }
    }

    my $ticket_id = $ticket->id;

    # ticket id could have utf8 flag on On Oracle :/
    if ( utf8::is_utf8($ticket_id) ) {
        $ticket_id = Encode::encode( 'UTF-8', $ticket_id );
    }

    RT::Test->run_and_capture(
        command     => $RT::SbinPath . '/rt-munge-attachments',
        tickets     => $ticket_id,
        search      => 'Grüßen',
        replacement => 'anonymous',
    );

    RT::Test->run_and_capture(
        command     => $RT::SbinPath . '/rt-munge-attachments',
        tickets     => $ticket_id,
        search      => '"Stever, Gregor" <gst@example.com>',
        replacement => 'anon@example.com',
    );

    $attachments = $ticket->Attachments( WithHeaders => 1, WithContent => 1 );
    while ( my $att = $attachments->Next ) {
        my $decoded_umlaut = Encode::decode( 'UTF-8', 'Grüßen' );
        if ( $att->Content ) {
            unlike( $att->Content, qr/$decoded_umlaut/, "Content lacks $decoded_umlaut" );
            like( $att->Content, qr/anonymous/, 'Content contains anonymous' );
        }
        else {
            unlike( $att->Headers, qr/"Stever, Gregor" <gst\@example.com>/, 'Headers lack gst@example.com' );
            like( $att->Headers, qr/anon\@example.com/, 'Headers contain anon@example.com' );
        }
    }
}

diag "Content returns a character string even when Content-Type is missing or oddly labelled";
{
    require HTML::Entities;

    # Pure ASCII body, so nothing but the entities can introduce a
    # non-ASCII character.  Also valid UTF-7, since it contains no "+".
    my $body = '<div>&nbsp;&copy;</div>';

    my %case = (
        'no Content-Type header at all' => sub {
            my $att = shift;
            $att->DelHeader('Content-Type');
        },
        'Content-Type with no space after the colon' => sub {
            my $att = shift;
            my $headers = $att->_Value('Headers');
            $headers =~ s/^Content-Type:\s+/Content-Type:/mi;
            $att->__Set( Field => 'Headers', Value => $headers );
        },
        'charset="UTF-7", which Encode decodes without upgrading' => sub {
            my $att = shift;
            $att->SetHeader( 'Content-Type' => 'text/html; charset="UTF-7"' );
        },
    );

    for my $desc ( sort keys %case ) {
        my $att = RT::Attachment->new( RT->SystemUser );
        my ($id) = $att->Create(
            TransactionId => 1,
            Attachment    => MIME::Entity->build(
                Type => 'text/html; charset="UTF-8"',
                Data => [$body],
            ),
        );
        ok( $id, "created attachment for: $desc" );

        $case{$desc}->($att);

        $att = RT::Attachment->new( RT->SystemUser );
        $att->Load($id);
        is( $att->ContentType, 'text/html', "ContentType column is still text/html ($desc)" );

        my $content = $att->Content;
        ok( utf8::is_utf8($content), "Content is a character string, not octets ($desc)" );
        is( $content, $body, "Content round-trips unchanged ($desc)" );

        # The failure this guards against: decoding entities into an octet
        # string yields bare \xA0/\xA9, which MySQL rejects with error 1366
        # when rt-fulltext-indexer binds it to a utf8mb4 column.
        HTML::Entities::decode_entities($content);
        is( $content, "<div>\x{00a0}\x{00a9}</div>",
            "entities decode to the expected codepoints ($desc)" );
        # Encode::encode would upgrade the string for us, hiding the bug.
        # DBD does no such thing: it binds the SV's internal buffer, which is
        # what _utf8_off exposes.  Bare \xA0/\xA9 here is what MySQL rejects.
        my $bound = $content;
        Encode::_utf8_off($bound);
        is( $bound, "<div>\xc2\xa0\xc2\xa9</div>",
            "internal bytes are valid UTF-8, as bound by DBD ($desc)" );
    }
}

diag "Header methods accept a header with no space after the colon";
{
    my $att = RT::Attachment->new( RT->SystemUser );
    my ($id) = $att->Create(
        TransactionId => 1,
        Attachment    => MIME::Entity->build(
            Type => 'text/plain; charset="UTF-8"',
            Data => ['hi'],
        ),
    );
    ok( $id, 'created attachment for no-space header tests' );

    $att->__Set(
        Field => 'Headers',
        Value => "X-Test:no-space\nX-Test-Other: spaced\n",
    );

    is( $att->GetHeader('X-Test'), 'no-space',
        'GetHeader finds a header with no space after the colon' );
    is_deeply( [ $att->GetAllHeaders('X-Test') ], ['no-space'],
        'GetAllHeaders finds a header with no space after the colon' );

    # Without the match, SetHeader falls through and appends a second
    # X-Test rather than replacing the one already there.  Count the raw
    # header lines: GetAllHeaders would miss the stale no-space one.
    $att->SetHeader( 'X-Test' => 'replaced' );
    is( scalar( grep { /^X-Test:/i } $att->_SplitHeaders ), 1,
        'SetHeader leaves exactly one X-Test header, not a duplicate' );
    is_deeply( [ $att->GetAllHeaders('X-Test') ], ['replaced'],
        'SetHeader replaces the value of a no-space header' );

    $att->DelHeader('X-Test');
    is( scalar( grep { /^X-Test:/i } $att->_SplitHeaders ), 0,
        'DelHeader removes a no-space header' );
    is( $att->GetHeader('X-Test-Other'), 'spaced',
        'DelHeader leaves the unrelated header alone' );
}

done_testing();
