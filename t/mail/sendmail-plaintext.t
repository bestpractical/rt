use strict;
use warnings;

use RT::Test tests => undef, text_templates => 1;

use File::Spec ();
use Email::Abstract;

# We're not testing acls here.
my $everyone = RT::Group->new(RT->SystemUser);
$everyone->LoadSystemInternalGroup('Everyone');
$everyone->PrincipalObj->GrantRight( Right =>'SuperUser' );

# some utils
sub first_txn    { return $_[0]->Transactions->First }
sub first_attach { return first_txn($_[0])->Attachments->First }
sub count_attachs { return first_txn($_[0])->Attachments->Count }

sub mail_in_ticket {
    my ($filename) = @_;
    my $path = RT::Test::get_relocatable_file($filename,
        (File::Spec->updir(), 'data', 'emails'));
    my $content = RT::Test->file_content($path);

    RT::Test->clean_caught_mails;
    my ($status, $id) = RT::Test->send_via_mailgate( $content );
    ok( !$status, "Fed $filename into mailgate");

    my $ticket = RT::Ticket->new(RT->SystemUser);
    $ticket->Load($id);
    ok( $ticket->Id, "Successfully created ticket ".$ticket->Id);

    my @mail = map {Email::Abstract->new($_)->cast('MIME::Entity')}
        RT::Test->fetch_caught_mails;
    return ($ticket, @mail);
}

{
    my ($ticket) = mail_in_ticket('multipart-report');
    like( first_txn($ticket)->Content , qr/The original message was received/, "It's the bounce");
}

for my $encoding ('ISO-8859-1', 'UTF-8') {
    RT->Config->Set( EmailOutputEncoding => $encoding );

    my ($ticket, @mail) = mail_in_ticket('new-ticket-from-iso-8859-1');
    like (first_txn($ticket)->Content , qr/H\x{e5}vard/, "It's signed by havard. yay");

    is(@mail, 1);
    like( $mail[0]->head->get('Content-Type') , qr/$encoding/,
          "Its content type is $encoding" );
    my $message_as_string = $mail[0]->bodyhandle->as_string();
    $message_as_string = Encode::decode($encoding, $message_as_string);
    like( $message_as_string , qr/H\x{e5}vard/,
          "The message's content contains havard's name in $encoding");
}

{
    my ($ticket) = mail_in_ticket('multipart-alternative-with-umlaut');
    like( first_txn($ticket)->Content, qr/causes Error/,
          "We recorded the content as containing 'causes error'");
    is( count_attachs($ticket), 3,
        "Has three attachments, presumably a text-plain, a text-html and a multipart alternative");
}

{
    my ($ticket, @mail) = mail_in_ticket('text-html-with-umlaut');
    like( first_attach($ticket)->Content, qr/causes Error/,
          "We recorded the content as containing 'causes error'");
    like( first_attach($ticket)->ContentType , qr/text\/html/,
          "We recorded the content as text/html");
    is (count_attachs($ticket), 1,
        "Has one attachment, just a text-html");

    is(@mail, 1);
    is( $mail[0]->parts, 0, "generated correspondence mime entity does not have parts");
    is( $mail[0]->head->mime_type , "text/plain", "The mime type is a plain");
}

{
    my @InputEncodings = RT->Config->Get('EmailInputEncodings');
    RT->Config->Set( EmailInputEncodings => 'koi8-r', @InputEncodings );
    RT->Config->Set( EmailOutputEncoding => 'koi8-r' );

    my ($ticket, @mail) = mail_in_ticket('russian-subject-no-content-type');
    like( first_attach($ticket)->ContentType, qr/text\/plain/,
          "We recorded the content type right");
    is( count_attachs($ticket), 1,
        "Has one attachment, presumably a text-plain");
    is( $ticket->Subject, Encode::decode("UTF-8","тест тест"),
        "Recorded the subject right");

    is(@mail, 1);
    is( $mail[0]->head->mime_type , "text/plain", "The only part is text/plain ");
    like( $mail[0]->head->get("subject"), qr/\Q=?KOI8-R?B?W2V4YW1wbGUuY29tICM2XSBBdXRvUmVwbHk6INTF09Qg1MXT1A==?=\E/,
          "The subject is encoded correctly");

    RT->Config->Set(EmailInputEncodings => @InputEncodings );
    RT->Config->Set(EmailOutputEncoding => 'utf-8');
}

{
    my ($ticket, @mail) = mail_in_ticket('nested-rfc-822');
    is( $ticket->Subject, "[Jonas Liljegren] Re: [Para] Niv\x{e5}er?");
    like( first_attach($ticket)->ContentType, qr/multipart\/mixed/,
          "We recorded the content type right");
    is( count_attachs($ticket), 5,
        "Has five attachments, presumably a text-plain and a message RFC 822 and another plain");

    is(@mail, 1);
    is( $mail[0]->head->mime_type , "text/plain", "The outgoing mail is plain text");

    my $encoded_subject = $mail[0]->head->get("Subject");
    chomp $encoded_subject;
    my $subject = Encode::decode('MIME-Header',$encoded_subject);
    like($subject, qr/Niv\x{e5}er/, "The subject matches the word - $subject");
}

{
    my ($ticket) = mail_in_ticket('notes-uuencoded');
    like( first_txn($ticket)->Content, qr/from Lotus Notes/,
         "We recorded the content right");
    is( count_attachs($ticket), 3, "Has three attachments");
}

{
    my ($ticket) = mail_in_ticket('crashes-file-based-parser');
    like( first_txn($ticket)->Content, qr/FYI/, "We recorded the content right");
    is( count_attachs($ticket), 5, "Has five attachments");
}

{
    my ($ticket) = mail_in_ticket('rt-send-cc');
    my $cc = first_attach($ticket)->GetHeader('RT-Send-Cc');
    like ($cc, qr/test$_/, "Found test $_") for 1..5;
}

{
    diag "Regression test for #5248 from rt3.fsck.com";
    my ($ticket) = mail_in_ticket('subject-with-folding-ws');
    is ($ticket->Subject, 'test', 'correct subject');
}

{
    diag "Regression test for #5248 from rt3.fsck.com";
    my ($ticket) = mail_in_ticket('very-long-subject');
    is ($ticket->Subject, '0123456789'x20, 'correct subject');
}

done_testing;
