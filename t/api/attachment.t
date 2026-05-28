
use strict;
use warnings;
use RT;
use RT::Test tests => undef;
use MIME::Entity;

# Helper: create a ticket via SystemUser with an attachment whose MIME
# filename is $name. Returns ($ticket, $attachment_with_name).
sub _create_ticket_with_attachment {
    my (%args)   = @_;
    my $subject  = $args{Subject}  // 'attachment test';
    my $filename = $args{Filename} // 'foo.txt';
    my $body     = $args{Body}     // "attachment body for $filename";

    my $mime = MIME::Entity->build(
        From    => 'test@example.com',
        Subject => $subject,
        Type    => 'text/plain',
        Data    => ['initial body'],
    );
    $mime->attach(
        Type     => $args{Type} // 'text/plain',
        Filename => $filename,
        Data     => [$body],
        ( $args{Encoding} ? ( Encoding => $args{Encoding} ) : () ),
    );

    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => $subject, MIMEObj => $mime );

    my $atts = RT::Attachments->new( RT->SystemUser );
    $atts->LimitByTicket( $ticket->Id );
    $atts->Limit( FIELD => 'Filename', VALUE => $filename );
    my $att = $atts->First;
    ok( $att && $att->Id, "found attachment $filename on ticket " . $ticket->Id );
    return ( $ticket, $att );
}


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

diag 'AddAttachment writes sanitized filename to transaction Data';
{
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'sanitize test' );

    my $mime = MIME::Entity->build(
        Type     => 'application/octet-stream',
        Filename => '../../evil.exe',
        Data     => ['malicious'],
    );

    my ( $txn_id, $msg ) = $ticket->AddAttachment( MIMEObj => $mime );
    ok( $txn_id, "AddAttachment returned txn id: $msg" );

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load($txn_id);
    is( $txn->Type, 'AddAttachment', 'transaction is AddAttachment' );
    is( $txn->Data, 'evil.exe',      'transaction Data is sanitized basename, not the full path' );

    my $atts = RT::Attachments->new( RT->SystemUser );
    $atts->Limit( FIELD => 'TransactionId', VALUE => $txn_id );
    $atts->Limit( FIELD => 'Filename',      VALUE => 'evil.exe' );
    is( $atts->Count, 1, 'stored attachment row Filename matches sanitized basename' );
}

diag 'DeleteAttachment rejects cross-ticket attachment';
{
    my ($ticket_a) = _create_ticket_with_attachment( Filename => 'a.txt' );
    ( undef, my $att_b ) = _create_ticket_with_attachment( Filename => 'b.txt' );

    my ( $ret, $msg ) = $ticket_a->DeleteAttachment($att_b);
    ok( !$ret, 'cross-ticket DeleteAttachment failed' );
    like( $msg, qr/does not belong to ticket/, "rejection message: $msg" );

    my $check = RT::Attachment->new( RT->SystemUser );
    $check->Load( $att_b->Id );
    ok( $check->Id, 'cross-ticket attachment still exists' );
    is( $check->Filename, 'b.txt', 'cross-ticket attachment Filename unchanged' );
}

diag 'DeleteAttachment preserves filename and content on the transaction';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'preserved.txt' );
    my $original_content = $att->Content;
    my ( $ret, $msg )    = $ticket->DeleteAttachment($att);
    ok( $ret, "DeleteAttachment succeeded: $msg" );

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load($ret);
    is( $txn->Type, 'DeleteAttachment', 'DeleteAttachment txn created' );
    is( $txn->Data, 'preserved.txt',    'filename preserved in Data for display' );
    is( $txn->OldValue, $original_content, 'attachment content preserved in OldValue' );
}

diag 'DeleteAttachment spills long content to RT::ObjectContent';
{
    my $long_body = 'x' x 1024;    # well over the 255-byte OldValue inline cap
    my ( $ticket, $att ) = _create_ticket_with_attachment(
        Filename => 'big.txt',
        Body     => $long_body,
    );

    my ( $ret, $msg ) = $ticket->DeleteAttachment($att);
    ok( $ret, "DeleteAttachment succeeded: $msg" );

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load($ret);
    is( $txn->ReferenceType, 'RT::ObjectContent', 'long content spilled to RT::ObjectContent' );
    is( $txn->OldValue, $long_body, 'OldValue accessor transparently returns spilled content' );
}

diag 'DeleteAttachment spills short binary content to RT::ObjectContent';
{
    # Short payload (well under 255 bytes) with a NUL byte: the length-based
    # spill path is NOT what we're testing here -- the new binary-detection
    # branch in RT::Transaction::Create has to be what triggers the spill.
    my $binary = "bin\x00\xffdata";
    my ( $ticket, $att ) = _create_ticket_with_attachment(
        Filename => 'binary.bin',
        Body     => $binary,
        Type     => 'application/octet-stream',
        Encoding => 'base64',
    );

    my $content = $att->Content;
    ok( length($content) < 255, 'binary content is short, so the length-based spill path does not apply' );
    like( $content, qr/\x00/, 'attachment Content roundtrips with NUL byte intact' );

    my ( $ret, $msg ) = $ticket->DeleteAttachment($att);
    ok( $ret, "DeleteAttachment succeeded: $msg" );

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load($ret);
    is( $txn->ReferenceType, 'RT::ObjectContent',
        'short binary OldValue spilled to RT::ObjectContent via the binary-detection branch' );
    is( $txn->OldValue, $binary, 'OldValue accessor returns the binary content unchanged' );
}

diag 'AddAttachment rejects uploads whose sanitized filename is empty';
{
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'puredot' );

    my $mime = MIME::Entity->build(
        Type     => 'text/plain',
        Filename => '..',
        Data     => ['body'],
    );

    my ( $ret, $msg ) = $ticket->AddAttachment( MIMEObj => $mime );
    ok( !$ret, "AddAttachment refused the upload: $msg" );
    like( $msg, qr/Invalid filename/, 'rejection message is "Invalid filename"' );

    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'AddAttachment' );
    is( $txns->Count, 0, 'no AddAttachment transaction recorded for rejected upload' );
}

diag 'RenameAttachment rejects cross-ticket attachment';
{
    my ($ticket_a) = _create_ticket_with_attachment( Filename => 'a2.txt' );
    ( undef, my $att_b ) = _create_ticket_with_attachment( Filename => 'b2.txt' );

    my ( $ret, $msg ) = $ticket_a->RenameAttachment( $att_b, 'pwned.txt' );
    ok( !$ret, 'cross-ticket RenameAttachment failed' );
    like( $msg, qr/does not belong to ticket/, "rejection message: $msg" );

    my $check = RT::Attachment->new( RT->SystemUser );
    $check->Load( $att_b->Id );
    is( $check->Filename, 'b2.txt', 'cross-ticket attachment Filename unchanged' );
}

diag 'PinAttachment / UnpinAttachment reject cross-ticket attachment';
{
    my ( $ticket_a, $att_a ) = _create_ticket_with_attachment( Filename => 'a3.txt' );
    ( undef, my $att_b ) = _create_ticket_with_attachment( Filename => 'b3.txt' );

    my ( $ret, $msg ) = $ticket_a->PinAttachment($att_b);
    ok( !$ret, 'cross-ticket PinAttachment failed' );
    like( $msg, qr/does not belong to ticket/, "Pin rejection message: $msg" );

    ( $ret, $msg ) = $ticket_a->PinAttachment($att_a);
    ok( $ret, "pinned own attachment: $msg" );

    ( $ret, $msg ) = $ticket_a->UnpinAttachment($att_b);
    ok( !$ret, 'cross-ticket UnpinAttachment failed' );
    like( $msg, qr/does not belong to ticket/, "Unpin rejection message: $msg" );

    my @pinned = $ticket_a->PinnedAttachments;
    is_deeply( [ sort @pinned ], ['a3.txt'], 'own pin remains after failed cross-ticket unpin' );
}

diag 'RenameAttachment rejects names that sanitize_filename rejects';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'rename_invalid.txt' );

    for my $bad ( undef, '', '   ', '.', '..', '...' ) {
        my $label = defined $bad ? "'$bad'" : '(undef)';
        my ( $ret, $msg ) = $ticket->RenameAttachment( $att, $bad );
        ok( !$ret, "rename to $label rejected: $msg" );
        like( $msg, qr/Invalid filename/, 'got Invalid filename error' );
    }

    my $too_long = ( 'a' x 256 );
    my ( $ret, $msg ) = $ticket->RenameAttachment( $att, $too_long );
    ok( !$ret, 'rename to >255-char name rejected' );
    like( $msg, qr/too long/i, 'got too-long error' );

    $att->Load( $att->Id );
    is( $att->Filename, 'rename_invalid.txt', 'attachment Filename unchanged after rejected renames' );
}

diag 'RenameAttachment silently sanitizes path components and control bytes';
{
    my %sanitized = (
        'foo/bar.txt'    => 'bar.txt',
        'foo\\bar.txt'   => 'bar.txt',
        "foo\x00bar.txt" => 'foo_bar.txt',
        "  spaced.txt  " => 'spaced.txt',
    );
    for my $input ( sort keys %sanitized ) {
        my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'pre_sanitize.txt' );
        my ( $ret, $msg ) = $ticket->RenameAttachment( $att, $input );
        ok( $ret, "rename to '$input' accepted: $msg" );
        $att->Load( $att->Id );
        is( $att->Filename, $sanitized{$input}, "stored as '$sanitized{$input}'" );
    }
}

diag 'RenameAttachment is a no-op when new name equals current name';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'same.txt' );

    my $txn_count_before = do {
        my $txns = $ticket->Transactions;
        $txns->Limit( FIELD => 'Type', VALUE => 'RenameAttachment' );
        $txns->Count;
    };

    my ( $ret, $msg ) = $ticket->RenameAttachment( $att, 'same.txt' );
    ok( !$ret, 'rename-to-same-name returned failure' );
    is( $msg, 'That is already the current value', 'got the standard no-op message' );

    my $txn_count_after = do {
        my $txns = $ticket->Transactions;
        $txns->Limit( FIELD => 'Type', VALUE => 'RenameAttachment' );
        $txns->Count;
    };
    is( $txn_count_after, $txn_count_before, 'no RenameAttachment transaction was recorded for no-op rename' );
}

diag 'RenameAttachment success path updates Filename and creates txn';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'before.txt' );
    my $att_id = $att->Id;

    my ( $ret, $msg ) = $ticket->RenameAttachment( $att, 'after.txt' );
    ok( $ret, "RenameAttachment returned success: $msg" );

    my $reloaded = RT::Attachment->new( RT->SystemUser );
    $reloaded->Load($att_id);
    is( $reloaded->Filename, 'after.txt', 'attachment Filename updated' );

    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type',  VALUE => 'RenameAttachment' );
    $txns->Limit( FIELD => 'Field', VALUE => $att_id );
    is( $txns->Count, 1, 'one RenameAttachment transaction created' );
    my $txn = $txns->First;
    is( $txn->OldValue, 'before.txt', 'txn OldValue is previous filename' );
    is( $txn->NewValue, 'after.txt',  'txn NewValue is new filename' );
}

diag 'RenameAttachment migrates the pin without spurious transactions';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'pinme.txt' );
    $ticket->PinAttachment($att);
    is_deeply( [ $ticket->PinnedAttachments ], ['pinme.txt'], 'attachment is pinned' );

    # A no-op rename of a pinned attachment must not unpin and re-pin it.
    $ticket->RenameAttachment( $att, 'pinme.txt' );
    is_deeply( [ $ticket->PinnedAttachments ], ['pinme.txt'], 'still pinned after no-op rename' );

    my $pin_txns = RT::Transactions->new( RT->SystemUser );
    $pin_txns->Limit( FIELD => 'ObjectType', VALUE => 'RT::Ticket' );
    $pin_txns->Limit( FIELD => 'ObjectId',   VALUE => $ticket->Id );
    $pin_txns->Limit( FIELD => 'Type', OPERATOR => 'IN', VALUE => [ 'PinAttachment', 'UnpinAttachment' ] );
    is( $pin_txns->Count, 1, 'no-op rename added no Pin/Unpin transactions' );

    # A real rename moves the pin to the new filename.
    $ticket->RenameAttachment( $att, 'pinned.txt' );
    is_deeply( [ $ticket->PinnedAttachments ], ['pinned.txt'], 'pin migrated to the new filename' );
}

diag 'DeleteAttachment drops the pin so a later same-name upload is not auto-pinned';
{
    my ( $ticket, $att ) = _create_ticket_with_attachment( Filename => 'pinned_then_deleted.txt' );
    $ticket->PinAttachment($att);
    is_deeply( [ $ticket->PinnedAttachments ], ['pinned_then_deleted.txt'], 'attachment is pinned' );

    my ( $ret, $msg ) = $ticket->DeleteAttachment($att);
    ok( $ret, "DeleteAttachment succeeded: $msg" );
    is_deeply( [ $ticket->PinnedAttachments ], [], 'pin dropped when the pinned attachment is deleted' );
}

diag 'DeleteAttachment keeps the pin while another attachment shares the filename';
{
    my ( $ticket, $att1 ) = _create_ticket_with_attachment( Filename => 'shared.txt' );

    my $mime = MIME::Entity->build( Type => 'text/plain', Filename => 'shared.txt', Data => ['second version'] );
    my ($txn_id) = $ticket->AddAttachment( MIMEObj => $mime );
    my $atts = RT::Attachments->new( RT->SystemUser );
    $atts->Limit( FIELD => 'TransactionId', VALUE => $txn_id );
    $atts->Limit( FIELD => 'Filename',      VALUE => 'shared.txt' );
    my $att2 = $atts->First;
    ok( $att2 && $att2->Id, 'second attachment sharing the filename created' );

    $ticket->PinAttachment($att1);
    is_deeply( [ $ticket->PinnedAttachments ], ['shared.txt'], 'filename is pinned' );

    my ( $ret, $msg ) = $ticket->DeleteAttachment($att1);
    ok( $ret, "deleted one of the shared attachments: $msg" );
    is_deeply( [ $ticket->PinnedAttachments ], ['shared.txt'],
        'pin kept while another attachment still has the filename' );

    ( $ret, $msg ) = $ticket->DeleteAttachment($att2);
    ok( $ret, "deleted the last shared attachment: $msg" );
    is_deeply( [ $ticket->PinnedAttachments ], [],
        'pin dropped once the last attachment with the filename is gone' );
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
