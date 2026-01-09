use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue->id, 'loaded queue';

my ($ok, $msg) = $queue->AddWatcher(
    Type    => 'AdminCc',
    Email   => 'test@example.com',
);
ok $ok, $msg;

my $mail = <<'.';
From: root@localhost
Subject: I like inline dispositions and I cannot lie
Content-type: multipart/related; boundary="foo"

--foo
Content-type: text/plain; charset="UTF-8"

ho hum just some text

--foo
Content-type: text/x-patch; name="filename.patch"
Content-disposition: inline; filename="filename.patch"

a fake patch

--foo
.

# inline
{
    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*inline.+?filename\.patch/is, 'found inline disposition';
}

# attachment
{
    $mail =~ s/(?<=Content-disposition: )inline/attachment/i;

    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*attachment.+?filename\.patch/is, 'found attachment disposition';
}

# no disposition
{
    $mail =~ s/^Content-disposition: .+?\n(?=\n)//ism;

    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*attachment.+?filename\.patch/is, 'found default (attachment) disposition';
}

# UTF-8 filename with narrow no-break space (U+202F) - common in macOS screenshot filenames
# This character appears between the time and AM/PM in filenames like:
# "Screenshot 2026-01-06 at 3.08.43 PM.png" (where the space before PM is U+202F)
# The filename must be RFC 2231 encoded in outgoing email to avoid SMTPUTF8 requirements
{
    # U+202F is encoded as \xE2\x80\xAF in UTF-8
    my $narrow_space = "\xE2\x80\xAF";
    my $utf8_mail = <<"END";
From: root\@localhost
Subject: Test UTF-8 attachment filename
Content-type: multipart/mixed; boundary="bar"

--bar
Content-type: text/plain; charset="UTF-8"

Testing attachment with UTF-8 filename

--bar
Content-type: image/png; name="Screenshot 2026-01-06 at 3.08.43${narrow_space}PM.png"
Content-disposition: attachment; filename="Screenshot 2026-01-06 at 3.08.43${narrow_space}PM.png"
Content-transfer-encoding: base64

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==
--bar--
END

    my $rt = send_and_receive($utf8_mail);

    # The filename should be RFC 2231 encoded with the U+202F percent-encoded as %E2%80%AF
    like $rt, qr/filename\*\s*=\s*"?UTF-8''[^"]*%E2%80%AF[^"]*PM\.png/i,
        'UTF-8 filename is RFC 2231 encoded with percent-encoded narrow no-break space';

    # Also verify the raw UTF-8 bytes are NOT present unencoded in Content-Disposition
    # (which would trigger SMTPUTF8 requirement)
    unlike $rt, qr/Content-Disposition:[^\n]*\xE2\x80\xAF/,
        'Raw UTF-8 bytes not present in Content-Disposition header';
}

sub send_and_receive {
    my $mail = shift;
    my ($stat, $id) = RT::Test->send_via_mailgate($mail);
    is( $stat >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "created ticket" );

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 2, "got 2 outgoing emails";

    # first is autoreply
    pop @mails;
}

done_testing;
