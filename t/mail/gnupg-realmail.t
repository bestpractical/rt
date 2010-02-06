use strict;
use warnings;

use RT::Test::GnuPG tests => 198, gnupg_options => { passphrase => 'rt-test' };

use Digest::MD5 qw(md5_hex);

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');
RT::Test->trust_gnupg_key('rt-test@example.com');

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we did log in';
$m->get_ok( '/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
         fields      => { CorrespondAddress => 'rt-recipient@example.com' } );
$m->content_like(qr/rt-recipient\@example.com.* - never/, 'has key info.');

my $eid = 0;
for my $usage (qw/signed encrypted signed&encrypted/) {
    for my $format (qw/MIME inline/) {
        for my $attachment (qw/plain text-attachment binary-attachment/) {
            ++$eid;
            diag "Email $eid: $usage, $attachment email with $format format";
            eval { email_ok($eid, $usage, $format, $attachment) };
        }
    }
}

$eid = 18;
{
    my ($usage, $format, $attachment) = ('signed', 'inline', 'plain');
    ++$eid;
    diag "Email $eid: $usage, $attachment email with $format format";
    eval { email_ok($eid, $usage, $format, $attachment) };
}

sub email_ok {
    my ($eid, $usage, $format, $attachment) = @_;
    diag "email_ok $eid: $usage, $format, $attachment";

    my $emaildatadir = RT::Test::get_relocatable_dir(File::Spec->updir(),
        qw(data gnupg emails));
    my ($file) = glob("$emaildatadir/$eid-*");
    my $mail = RT::Test->file_content($file);

    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "$eid: The mail gateway exited normally");
    ok ($id, "$eid: got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "$eid: loaded ticket #$id");

    is ($tick->Subject,
        "Test Email ID:$eid",
        "$eid: Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        "$eid: recorded incoming mail that is encrypted"
    );

    if ($usage =~ /encrypted/) {
        if ( $format eq 'MIME' || $attachment eq 'plain' ) {
            is( $msg->GetHeader('X-RT-Incoming-Encryption'),
                'Success',
                "$eid: recorded incoming mail that is encrypted"
            );
        } else {
            is( $attachments[0]->GetHeader('X-RT-Incoming-Encryption'),
                'Success',
                "$eid: recorded incoming mail that is encrypted"
            );
            is( $attachments[1]->GetHeader('X-RT-Incoming-Encryption'),
                'Success',
                "$eid: recorded incoming mail that is encrypted"
            );
        }
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
# XXX: FIXME: TODO: 6-signed-inline-with-attachment should be re-generated as it's actually RFC format
        if ( $format eq 'MIME' || $attachment eq 'plain' || ($format eq 'inline' && $attachment =~ /binary/ && $usage !~ /encrypted/) ) {
            is( $msg->GetHeader('X-RT-Incoming-Signature'),
                'RT Test <rt-test@example.com>',
                "$eid: recorded incoming mail that is signed"
            );
        }
        else {
            is( $attachments[0]->GetHeader('X-RT-Incoming-Signature'),
                'RT Test <rt-test@example.com>',
                "$eid: recorded incoming mail that is signed"
            );
            is( $attachments[1]->GetHeader('X-RT-Incoming-Signature'),
                'RT Test <rt-test@example.com>',
                "$eid: recorded incoming mail that is signed"
            );
        }
    }
    else {
        is( $msg->GetHeader('X-RT-Incoming-Signature'),
            undef,
            "$eid: recorded incoming mail that is not signed"
        );
    }

    if ($attachment =~ /attachment/) {
        # signed messages should sign each attachment too
        if ($usage =~ /signed/) {
            my $sig = pop @attachments;
            ok ($sig->Id, "$eid: loaded attachment.sig object");
            my $acontent = $sig->Content;
        }

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

