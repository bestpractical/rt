
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

diag 'RT::Util::sanitize_filename';
{
    require RT::Util;
    RT::Util->import('sanitize_filename');

    # Plain filename round-trips unchanged.
    is( RT::Util::sanitize_filename('report.pdf'), 'report.pdf', 'plain filename passes through' );

    # Unix path traversal.
    is( RT::Util::sanitize_filename('../../etc/passwd'), 'passwd', 'unix path components stripped' );

    # Windows path traversal.
    is( RT::Util::sanitize_filename('..\\..\\evil.exe'), 'evil.exe', 'windows path components stripped' );

    # Mixed separators.
    is( RT::Util::sanitize_filename('foo/bar\\baz/qux.txt'),
        'qux.txt', 'mixed unix/windows path components stripped' );

    # Pure-dot names rejected.
    is( RT::Util::sanitize_filename('.'),   undef, 'single dot is rejected' );
    is( RT::Util::sanitize_filename('..'),  undef, 'double dot is rejected' );
    is( RT::Util::sanitize_filename('...'), undef, 'triple dot is rejected' );

    # Pure-dot names AFTER path strip rejected.
    is( RT::Util::sanitize_filename('some/path/..'), undef, 'pure-dot after path strip is rejected' );

    # Empty / whitespace-only input rejected.
    is( RT::Util::sanitize_filename(''),    undef, 'empty string is rejected' );
    is( RT::Util::sanitize_filename('   '), undef, 'spaces-only is rejected' );

    # Undef input.
    is( RT::Util::sanitize_filename(undef), undef, 'undef returns undef' );

    # Whitespace trimming (spaces only — tabs/newlines are C0 control bytes
    # and get replaced with underscores BEFORE the trim step).
    is( RT::Util::sanitize_filename('  report.pdf  '), 'report.pdf', 'surrounding spaces trimmed' );
    is( RT::Util::sanitize_filename("\treport.pdf\n"),
        '_report.pdf_', 'tab/newline are control bytes, not whitespace to trim' );

    # Control byte neutralization.
    is( RT::Util::sanitize_filename("foo\x00bar"),  'foo_bar', 'NUL byte replaced with underscore' );
    is( RT::Util::sanitize_filename("foo\x7fbar"),  'foo_bar', 'DEL byte replaced with underscore' );
    is( RT::Util::sanitize_filename("a\x01b\x1fc"), 'a_b_c',   'C0 control bytes each replaced' );

    # Path component containing control bytes — the control bytes are in the
    # stripped prefix so they vanish entirely with the path.
    is( RT::Util::sanitize_filename("\x00\x01evil/foo.txt"),
        'foo.txt', 'control bytes in stripped path components are discarded with the path' );

    # Path strip happens before control-byte trim: the basename retains its
    # control byte, which then becomes an underscore.
    is( RT::Util::sanitize_filename("foo/bar\x00baz"),
        'bar_baz', 'path stripped first, then control bytes in basename neutralized' );

    # The 255-char cap is NOT enforced here; RenameAttachment enforces it
    # separately. Confirm pass-through for a 1000-char name.
    my $long = 'a' x 1000;
    is( RT::Util::sanitize_filename($long), $long, 'sanitize_filename does not enforce 255-char limit' );

    # sanitize_filename is exported from RT::Util.
    {
        no strict 'refs';
        ok( defined &{'main::sanitize_filename'}, 'sanitize_filename is exported into caller' );
    }
    is( sanitize_filename('../foo.txt'), 'foo.txt', 'exported sanitize_filename works without package prefix' );
}

done_testing();
