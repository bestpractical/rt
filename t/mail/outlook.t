use strict;
use warnings;

use RT::Test tests => 42;

# 12.0 is outlook 2007, 14.0 is 2010
for my $mailer ( 'Microsoft Office Outlook 12.0', 'Microsoft Outlook 14.0' ) {
    diag "Test mail with multipart/alternative";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

here is the content



blahmm

another line


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>


------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

        my $content = <<EOF;
here is the content

blahmm
another line
EOF
        test_email( $text, $content,
            $mailer . ' with multipart/alternative, \n\n are replaced' );
    }

    diag "Test mail with multipart/mixed, with multipart/alternative in it";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/mixed;
	boundary="----=_NextPart_000_000F_01CB045E.5222CB40"

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: multipart/alternative;
	boundary="----=_NextPart_001_0010_01CB045E.5222CB40"


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>

------=_NextPart_001_0010_01CB045E.5222CB40--

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: text/plain;
	name="att.txt"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: attachment;
	filename="att.txt"

this is the attachment! :)=0A=

------=_NextPart_000_000F_01CB045E.5222CB40--
EOF

        my $content = <<EOF;
foo

bar
baz
EOF
        test_email( $text, $content,
            $mailer . ' with multipart/multipart, \n\n are replaced' );
    }

    diag "Test mail with with outlook, but the content type is text/plain";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz

EOF

        my $content = <<EOF;
foo



bar

baz

EOF
        test_email( $text, $content,
            $mailer . ' with only text/plain, \n\n are not replaced' );
    }
}

diag "Test mail with with multipart/alternative but x-mailer is not outlook ";
{
    my $text = <<EOF;
From: root\@localhost
X-Mailer: Mutt
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>


------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

    my $content = <<EOF;
foo



bar

baz

EOF
    test_email( $text, $content, 'without outlook, \n\n are not replaced' );
}

sub test_email {
    my ( $text, $content, $msg ) = @_;
    my ( $status, $id ) = RT::Test->send_via_mailgate($text);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket" );

    my $ticket = RT::Test->last_ticket;
    isa_ok( $ticket, 'RT::Ticket' );
    is( $ticket->Id, $id, "correct ticket id" );
    is( $ticket->Subject, 'outlook basic test', "subject of ticket $id" );
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Create' );
    my $txn     = $txns->First;

    is( $txn->Content, $content, $msg );
}

