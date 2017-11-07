use strict;
use warnings;

use RT::Test::SMIME tests => undef;
use Digest::MD5 qw(md5_hex);

my $test = 'RT::Test::SMIME';
my $mails = $test->mail_set_path;

RT->Config->Get('SMIME')->{AcceptUntrustedCAs} = 1;

RT::Test::SMIME->import_key('root@example.com');
RT::Test::SMIME->import_key('sender@example.com');

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we did log in';
$m->get_ok( '/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
         fields      => { CorrespondAddress => 'root@example.com' } );

diag "load Everyone group" if $ENV{'TEST_VERBOSE'};
my $everyone;
{
    $everyone = RT::Group->new( $RT::SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok $everyone->id, "loaded 'everyone' group";
}

RT::Test->set_rights(
    Principal => $everyone,
    Right => ['CreateTicket'],
);


my $eid = 0;
for my $usage (qw/signed encrypted signed&encrypted/) {
    for my $attachment (qw/plain text-attachment binary-attachment/) {
        ++$eid;
        diag "Email $eid: $usage, $attachment email" if $ENV{TEST_VERBOSE};
        eval { email_ok($eid, $usage, $attachment) };
    }
}

done_testing;

sub email_ok {
    my ($eid, $usage, $attachment) = @_;
    diag "email_ok $eid: $usage, $attachment" if $ENV{'TEST_VERBOSE'};

    my ($file) = glob("$mails/$eid-*");
    my $mail = RT::Test->file_content($file);

    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "$eid: The mail gateway exited normally");
    ok ($id, "$eid: got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "$eid: loaded ticket #$id");

    is ($tick->Subject,
        "Test Email ID:$eid",
        "$eid: Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'SMIME',
        "$eid: recorded incoming mail that is secured"
    );

    if ($usage =~ /encrypted/) {
        is( $msg->GetHeader('X-RT-Incoming-Encryption'),
            'Success',
            "$eid: recorded incoming mail that is encrypted"
        );
        like( $attachments[0]->Content, qr/ID:$eid/,
                "$eid: incoming mail did NOT have original body"
        );
    }
    else {
        is( $msg->GetHeader('X-RT-Incoming-Encryption'),
            'Not encrypted',
            "$eid: recorded incoming mail that is not encrypted"
        );
        like( $msg->Content || $attachments[0]->Content, qr/ID:$eid/,
            "$eid: got original content"
        );
    }

    if ($usage =~ /signed/) {
        is( $msg->GetHeader('X-RT-Incoming-Signature'),
            '"sender" <sender@example.com>',
            "$eid: recorded incoming mail that is signed"
        );
    }
    else {
        is( $msg->GetHeader('X-RT-Incoming-Signature'),
            undef,
            "$eid: recorded incoming mail that is not signed"
        );
    }

    if ($attachment =~ /attachment/) {
        my ($a) = grep $_->Filename, @attachments;
        ok ($a && $a->Id, "$eid: found attachment with filename");

        my $acontent = $a->Content;
        if ($attachment =~ /binary/)
        {
            is(md5_hex($acontent), '1e35f1aa90c98ca2bab85c26ae3e1ba7', "$eid: The binary attachment's md5sum matches");
        }
        else
        {
            like($acontent, qr/zanzibar/, "$eid: The attachment isn't screwed up in the database.");
        }
    }

    return 0;
}

