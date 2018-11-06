use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set('CheckMoreMSMailHeaders', 1);

# 12.0 is outlook 2007, 14.0 is 2010
for my $mailer ( 'Microsoft Office Outlook 12.0', 'Microsoft Outlook 14.0' ) {
    diag "Test mail with multipart/alternative (in-the-wild case)";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
\tboundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
content-type: text/plain; charset="utf-8"
Content-Transfer-Encoding: quoted-printable

Hi,


What's the best way to add a new line in the below callback, I tried adding \\n but it didn't work.




package RT::Transaction;
use strict;
use warnings;
no warnings 'redefine';

sub QuoteHeader {
    my \$self = shift;
    if (\$self->Object->isa('RT::Ticket')) {
       return \$self->loc("On [_1], [_2] wrote:\nTo: [_3]\nCc: [_4]", \$self->CreatedAsString, \$self->Object->QueueObj->CorrespondAddress,\$self->TicketObj->RequestorAddresses,\$self->TicketObj->CcAddresses);
    }
    return \$self->loc("On [_1], [_2] wrote:\nTo: [_3]\nCc: [_4]", \$self->CreatedAsString, \$self->CreatorObj->Name,\$self->TicketObj->RequestorAddresses,\$self->TicketObj->CcAddresses);
}

1;

------=_NextPart_000_0004_01CB045C.A5A075D0
content-type: text/html; charset="utf-8"
Content-Transfer-Encoding: quoted-printable

<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css" style="display:none;"><!-- P {margin-top:0;margin-bottom:0;} --></style>
</head>
<body dir="ltr">
<div id="divtagdefaultwrapper" style="font-size:12pt;color:#000000;font-family:Calibri,Helvetica,sans-serif;" dir="ltr">
<p style="margin-top:0;margin-bottom:0">Hi,</p>
<p style="margin-top:0;margin-bottom:0"><br>
</p>
<p style="margin-top:0;margin-bottom:0">What's the best way to add a new line in the below callback, I tried adding
<span style="background-color: rgb(255, 255, 0);">\\n</span> but it didn't work.</p>
<p style="margin-top:0;margin-bottom:0"><br>
</p>
<p style="margin-top:0;margin-bottom:0"><br>
</p>
<p style="margin-top:0;margin-bottom:0"><br>
</p>
<p style="margin-top:0;margin-bottom:0"></p>
<div><span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">package RT::Transaction;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">use strict;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">use warnings;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">no warnings 'redefine';</span><br>
<br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">sub QuoteHeader {</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; my \$self = shift;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; if (\$self-&gt;Object-&gt;isa('RT::Ticket')) {</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; return \$self-&gt;loc(&quot;On [_1], [_2] wrote:<span style="background-color: rgb(255, 255, 0);">\n</span>To: [_3]<span style="background-color: rgb(255, 255, 0);">\n</span>Cc:
 [_4]&quot;, \$self-&gt;CreatedAsString, \$self-&gt;Object-&gt;QueueObj-&gt;CorrespondAddress,\$self-&gt;TicketObj-&gt;RequestorAddresses,\$self-&gt;TicketObj-&gt;CcAddresses);</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; }&nbsp; &nbsp;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; return \$self-&gt;loc(&quot;On [_1], [_2] wrote:<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);"><span style="background-color: rgb(255, 255, 0);">\n</span></span>To:
 [_3]<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);"><span style="background-color: rgb(255, 255, 0);">\n</span></span>Cc: [_4]&quot;, \$self-&gt;CreatedAsString, \$self-&gt;CreatorObj-&gt;Name,\$self-&gt;TicketObj-&gt;RequestorAddresses,\$self-&gt;TicketObj-&gt;CcAddresses);</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">}</span><br>
<br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">1;</span></div>
<br>
<p></p>
</div></body></html>

------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

        my $text_content = <<EOF;
Hi,

What's the best way to add a new line in the below callback, I tried adding \\n but it didn't work.


package RT::Transaction;
use strict;
use warnings;
no warnings 'redefine';
sub QuoteHeader {
    my \$self = shift;
    if (\$self->Object->isa('RT::Ticket')) {
       return \$self->loc("On [_1], [_2] wrote:\nTo: [_3]\nCc: [_4]", \$self->CreatedAsString, \$self->Object->QueueObj->CorrespondAddress,\$self->TicketObj->RequestorAddresses,\$self->TicketObj->CcAddresses);
    }
    return \$self->loc("On [_1], [_2] wrote:\nTo: [_3]\nCc: [_4]", \$self->CreatedAsString, \$self->CreatorObj->Name,\$self->TicketObj->RequestorAddresses,\$self->TicketObj->CcAddresses);
}
1;
EOF
        my $html_content = <<EOF;






<div id="divtagdefaultwrapper" style="font-size:12pt;color:#000000;font-family:Calibri,Helvetica,sans-serif;" dir="ltr">
<p style="margin-top:0;margin-bottom:0">Hi,</p>

<p style="margin-top:0;margin-bottom:0">What's the best way to add a new line in the below callback, I tried adding
<span style="background-color: rgb(255, 255, 0);">\\n</span> but it didn't work.</p>




<div><span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">package RT::Transaction;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">use strict;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">use warnings;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">no warnings 'redefine';</span><br>
<br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">sub QuoteHeader {</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; my \$self = shift;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; if (\$self-&gt;Object-&gt;isa('RT::Ticket')) {</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; return \$self-&gt;loc(&quot;On [_1], [_2] wrote:<span style="background-color: rgb(255, 255, 0);">
</span>To: [_3]<span style="background-color: rgb(255, 255, 0);">
</span>Cc:
 [_4]&quot;, \$self-&gt;CreatedAsString, \$self-&gt;Object-&gt;QueueObj-&gt;CorrespondAddress,\$self-&gt;TicketObj-&gt;RequestorAddresses,\$self-&gt;TicketObj-&gt;CcAddresses);</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; }&nbsp; &nbsp;</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">&nbsp;&nbsp;&nbsp; return \$self-&gt;loc(&quot;On [_1], [_2] wrote:<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);"><span style="background-color: rgb(255, 255, 0);">
</span></span>To:
 [_3]<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);"><span style="background-color: rgb(255, 255, 0);">
</span></span>Cc: [_4]&quot;, \$self-&gt;CreatedAsString, \$self-&gt;CreatorObj-&gt;Name,\$self-&gt;TicketObj-&gt;RequestorAddresses,\$self-&gt;TicketObj-&gt;CcAddresses);</span><br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">}</span><br>
<br>
<span style="font-family: Consolas, Courier, monospace; color: rgb(117, 123, 128);">1;</span></div>
<br>

</div>
EOF
        test_email( $text, $text_content,
                    $mailer . ' with multipart/alternative, \n\n are replaced' );
        test_email( $text, $html_content,
                    $mailer . ' with multipart/alternative, line-break-only paragraphs removed from the HTML part', "text/html" );
    }

    diag "Test mail with multipart/alternative";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
\tboundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
\tcharset="us-ascii"
Content-Transfer-Encoding: 7bit

here is the content



blahmm

another line


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
\tcharset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html><body><p>here is the content</p><p><br></p><p>another paragraph</p></body></html>

------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

        my $text_content = <<EOF;
here is the content

blahmm
another line
EOF
        my $html_content = <<EOF;
<p>here is the content</p><p>another paragraph</p>
EOF
        test_email( $text, $text_content,
                    $mailer . ' with multipart/alternative, \n\n are replaced' );
        test_email( $text, $html_content,
                    $mailer . ' with multipart/alternative, line-break-only paragraphs removed from the HTML part', "text/html" );
    }

    diag "Test mail with multipart/alternative";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
\tboundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
\tcharset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
\tcharset="us-ascii"
Content-Transfer-Encoding: 7bit

here is the content



blahmm

another line


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
\tboundary="----=_NextPart_000_000F_01CB045E.5222CB40"

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: multipart/alternative;
\tboundary="----=_NextPart_001_0010_01CB045E.5222CB40"


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/plain;
\tcharset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/html;
\tcharset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>

------=_NextPart_001_0010_01CB045E.5222CB40--

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: text/plain;
\tname="att.txt"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: attachment;
\tfilename="att.txt"

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

    diag "Test mail with with outlook, content type is base64";
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: base64

VGhpcyBpcyB0aGUgYm9keSBvZiBhbiBlbWFpbC4KCkl0IGhhcyBtdWx0aXBs
ZSBleHRyYSBuZXdsaW5lcy4KCgoKTGlrZSBhIG1hbmdsZWQgT3V0bG9vayBt
ZXNzYWdlIG1pZ2h0LgoKCgpKb2huIFNtaXRoCgpTb21lIENvbXBhbnkKCmVt
YWlsQHNvbWVjby5jb20KCg==
EOF

        my $content = <<EOF;
This is the body of an email.
It has multiple extra newlines.

Like a mangled Outlook message might.

John Smith
Some Company
email\@someco.com
EOF
        test_email( $text, $content,
            $mailer . ' with base64, \n\n are replaced' );
    }
}

# In a sample we received, the two X-MS- headers included
# below were both present and had no values. For now, using
# the existence of these headers as evidence of MS Outlook
# or Exchange.

diag "Test mail with with outlook, no X-Mailer, content type is base64";
{
        my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: base64
X-MS-Has-Attach:
X-MS-Tnef-Correlator:

VGhpcyBpcyB0aGUgYm9keSBvZiBhbiBlbWFpbC4KCkl0IGhhcyBtdWx0aXBs
ZSBleHRyYSBuZXdsaW5lcy4KCgoKTGlrZSBhIG1hbmdsZWQgT3V0bG9vayBt
ZXNzYWdlIG1pZ2h0LgoKCgpKb2huIFNtaXRoCgpTb21lIENvbXBhbnkKCmVt
YWlsQHNvbWVjby5jb20KCg==
EOF

        my $content = <<EOF;
This is the body of an email.
It has multiple extra newlines.

Like a mangled Outlook message might.

John Smith
Some Company
email\@someco.com
EOF
        test_email( $text, $content,
                    ' with base64, no X-Mailer, \n\n are replaced' );
}


diag "Test mail with with multipart/alternative but x-mailer is not outlook ";
{
    my $text = <<EOF;
From: root\@localhost
X-Mailer: Mutt
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
\tboundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
\tcharset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
\tcharset="us-ascii"
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

diag "Sample multipart email with Exchange headers";
{
        my $text = <<EOF;
X-MimeOLE: Produced By Microsoft Exchange V6.5
Received: by example.com
        id <01CD63FC.33F4C15C\@example.com>; Tue, 17 Jul 2012 10:11:51 +0100
MIME-Version: 1.0
Content-Type: multipart/alternative;
        boundary="----_=_NextPart_001_01CD63FC.33F4C15C"
Content-class: urn:content-classes:message
Subject: outlook basic test
Date: Tue, 17 Jul 2012 10:11:50 +0100
Message-ID: <AA6CEAFB02FF244999046B2A6B6B9D6F05FF9D12\@example.com>
X-MS-Has-Attach:
X-MS-TNEF-Correlator:
Thread-Topic: Testing Outlook HTML
Thread-Index: Ac1j/DNs7ly963bnRt63SJw9DkGwyw==
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}

This is a multi-part message in MIME format.

------_=_NextPart_001_01CD63FC.33F4C15C
Content-Type: text/plain;
        charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

This email contains a line of text containing multiple sentences.  Where
will RT wrap this when the text is quoted?  What about the footer below?

=20

This is a different line, with a blank line (paragraph) above.  Will
there be additional blank lines when the text is quoted?

=20

This isthesig

=20


------_=_NextPart_001_01CD63FC.33F4C15C
Content-Type: text/html;
        charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html xmlns:v=3D"urn:schemas-microsoft-com:vml" =
xmlns:o=3D"urn:schemas-microsoft-com:office:office" =
xmlns:w=3D"urn:schemas-microsoft-com:office:word" =
xmlns:m=3D"http://schemas.microsoft.com/office/2004/12/omml" =
xmlns=3D"http://www.w3.org/TR/REC-html40"><head><META =
HTTP-EQUIV=3D"Content-Type" CONTENT=3D"text/html; =
charset=3Dus-ascii"><meta name=3DGenerator content=3D"Microsoft Word 12 =
(filtered medium)"><style><!--
/* Font Definitions */
\@font-face
        {font-family:"Cambria Math";
        panose-1:2 4 5 3 5 4 6 3 2 4;}
\@font-face
        {font-family:Calibri;
        panose-1:2 15 5 2 2 2 4 3 2 4;}
/* Style Definitions */
p.MsoNormal, li.MsoNormal, div.MsoNormal
        {margin:0in;
        margin-bottom:.0001pt;
        font-size:11.0pt;
        font-family:"Calibri","sans-serif";}
a:link, span.MsoHyperlink
        {mso-style-priority:99;
        color:blue;
        text-decoration:underline;}
a:visited, span.MsoHyperlinkFollowed
        {mso-style-priority:99;
        color:purple;
        text-decoration:underline;}
span.EmailStyle17
        {mso-style-type:personal-compose;
        font-family:"Calibri","sans-serif";
        color:windowtext;}
.MsoChpDefault
        {mso-style-type:export-only;}
\@page WordSection1
        {size:8.5in 11.0in;
        margin:1.0in 1.0in 1.0in 1.0in;}
div.WordSection1
        {page:WordSection1;}
--></style><!--[if gte mso 9]><xml>
<o:shapedefaults v:ext=3D"edit" spidmax=3D"1026" />
</xml><![endif]--><!--[if gte mso 9]><xml>
<o:shapelayout v:ext=3D"edit">
<o:idmap v:ext=3D"edit" data=3D"1" />
</o:shapelayout></xml><![endif]--></head><body lang=3DEN-US link=3Dblue =
vlink=3Dpurple><div class=3DWordSection1><p class=3DMsoNormal>This email =
contains a line of text containing multiple sentences.&nbsp; Where will =
RT wrap this when the text is quoted?&nbsp; What about the footer =
below?<o:p></o:p></p><p class=3DMsoNormal><o:p>&nbsp;</o:p></p><p =
class=3DMsoNormal>This is a different line, with a blank line =
(paragraph) above.&nbsp; Will there be additional blank lines when the =
text is quoted?<o:p></o:p></p><p =
class=3DMsoNormal><o:p>&nbsp;</o:p></p><p class=3DMsoNormal><span =
lang=3DEN-GB =
style=3D'font-size:7.5pt;font-family:"Arial","sans-serif"'>This isthesig =
</span><o:p></o:p></p><p =
class=3DMsoNormal><o:p>&nbsp;</o:p></p></div></body></html>
------_=_NextPart_001_01CD63FC.33F4C15C--
EOF

        my $content = <<EOF;
This email contains a line of text containing multiple sentences.  Where
will RT wrap this when the text is quoted?  What about the footer below?

This is a different line, with a blank line (paragraph) above.  Will
there be additional blank lines when the text is quoted?

This isthesig

EOF

        test_email( $text, $content,
                    'Another sample multipart message with Exchange headers' );
}

sub test_email {
    my ( $text, $content, $msg, $check_type ) = @_;
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

    is( $txn->Content(Type => $check_type || "text/plain"), $content, $msg );
}

done_testing;
