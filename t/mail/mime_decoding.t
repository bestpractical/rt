use strict;
use warnings;
use RT::Test nodb => 1, tests => undef;
use Test::LongString;
use Test::Warn;

use_ok('RT::I18N');

diag q{'=' char in a leading part before an encoded part};
{
    my $str = 'key="plain"; key="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    warnings_like {
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            'key="plain"; key="мой_файл.bin"',
            "right decoding"
        );
    } [qr/DecodeMIMEWordsTo.*?called without field name/i];
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'content-disposition'),
        'key="plain"; key="мой_файл.bin"',
        "right decoding"
    );
}

diag q{not compliant with standards, but MUAs send such field when attachment has non-ascii in name};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    warnings_like {
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            'attachment; filename="мой_файл.bin"',
            "right decoding"
        );
    } [qr/DecodeMIMEWordsTo.*?called without field name/i];
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'content-disposition'),
        'attachment; filename="мой_файл.bin"',
        "right decoding"
    );
}

diag q{'=' char in a trailing part after an encoded part};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="; some_prop="value"';
    warnings_like {
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            'attachment; filename="мой_файл.bin"; some_prop="value"',
            "right decoding"
        );
    } [qr/DecodeMIMEWordsTo.*?called without field name/i];
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'content-disposition'),
        'attachment; filename="мой_файл.bin"; some_prop="value"',
        "right decoding"
    );
}

diag q{adding quotes around mime words containing specials when word is already quoted};
{
    my $str = 'attachment; filename="=?iso-8859-1?Q?foobar,_?=' . "\n" . '=?iso-8859-1?Q?barfoo.docx?="';
    my $decoded = 'attachment; filename="foobar, barfoo.docx"';
    is( RT::I18N::DecodeMIMEWordsToUTF8($str, 'content-disposition'), $decoded, "No added quotes" );
}

diag q{regression test for #5248 from rt3.fsck.com};
{
    my $str = qq{Subject: =?ISO-8859-1?Q?Re=3A_=5BXXXXXX=23269=5D_=5BComment=5D_Frag?=}
        . qq{\n =?ISO-8859-1?Q?e_zu_XXXXXX--xxxxxx_/_Xxxxx=FCxxxxxxxxxx?=};
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Subject'),
        qq{Subject: Re: [XXXXXX#269] [Comment] Frage zu XXXXXX--xxxxxx / Xxxxxüxxxxxxxxxx},
        "right decoding"
    );
}

diag q{newline and encoded file name};
{
    my $str = qq{application/vnd.ms-powerpoint;\n\tname="=?ISO-8859-1?Q?Main_presentation.ppt?="};
    warnings_like {
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            qq{application/vnd.ms-powerpoint;\tname="Main presentation.ppt"},
            "right decoding"
        );
    } [qr/DecodeMIMEWordsTo.*?called without field name/i];
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str,'content-type'),
        qq{application/vnd.ms-powerpoint; name="Main presentation.ppt"},
        "right decoding"
    );
}

diag q{rfc2231};
{
    my $str =
"attachment; filename*=ISO-8859-1''%74%E9%73%74%2E%74%78%74";
    is(
        RT::I18N::DecodeMIMEWordsToEncoding( $str, 'utf-8', 'Content-Disposition' ),
        'attachment; filename="tést.txt"',
        'right decoding'
    );
}

diag q{rfc2231 param continuations};
{
    # XXX TODO: test various forms of the continuation stuff
    #       quotes around the values
    my $hdr = <<'.';
inline;
 filename*0*=ISO-2022-JP'ja'%1b$B%3f7$7$$%25F%25%2d%259%25H%1b%28B;
 filename*1*=%20;
 filename*2*=%1b$B%25I%25%2d%25e%25a%25s%25H%1b%28B;
 filename*3=.txt
.
    is(
        RT::I18N::DecodeMIMEWordsToEncoding( $hdr, 'utf-8', 'Content-Disposition' ),
        'inline; filename="新しいテキスト ドキュメント.txt"',
        'decoded continuations as one string'
    );
}

diag q{canonicalize mime word encodings like gb2312};
{
    my $str = qq{Subject: =?gb2312?B?1NrKwL3nuPe12Lmy09CzrN9eX1NpbXBsaWZpZWRfQ05fR0IyMzEyYQ==?=
\t=?gb2312?B?dHRhY2hlbWVudCB0ZXN0IGluIENOIHNpbXBsaWZpZWQ=?=};

    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str, "Subject"),
        qq{Subject: 在世界各地共有超過_Simplified_CN_GB2312attachement test in CN simplified},
        "right decoding"
    );
}

diag q{Whitespace between encoded words should be removed};
{
    warnings_like {
        my $str = "=?utf-8?Q?=E3=82=AD?=    =?utf-8?Q?=E3=83=A3?=";
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            "キャ",
            "whitespace between encoded words is removed",
        );

        $str = "=?utf-8?Q?=E3=82=AD?=  \n   =?utf-8?Q?=E3=83=A3?=";
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            "キャ",
            "newlines between encoded words also removed",
        );
    } [(qr/DecodeMIMEWordsTo.*?called without field name/i) x 2];
}

diag q{Multiple octets split across QP hunks are correctly reassembled};
{
    warnings_like {
        # This passes even without explicit code to handle it because utf8
        # is perl's internal string encoding.
        my $str = "=?utf-8?Q?=E3?=    =?utf-8?Q?=82?=    =?utf-8?Q?=AD?=";
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            "キ",
            "UTF8 character split in three is successfully reassembled",
        );

        # Non-utf8 encodings thus also must be checked
        $str = <<EOT; chomp $str;
=?gb2312?q?Chinese(gb2312)=20=20=C3=C0=B9=FA=C7=B0=CB=BE=B7=A8=B2=BF=B3?=
 =?gb2312?q?=A4=C3=E6=BC=FB=C8=F8=B4=EF=C4=B7=BA=F3=B3=C6=C6=E4=D7=B4=CC=AC?=
 =?gb2312?q?=BA=DC=BA=C3=20=20Chinese=20(gb2312)?=
EOT
        is(
            RT::I18N::DecodeMIMEWordsToUTF8($str),
            "Chinese(gb2312)  美国前司法部长面见萨达姆后称其状态很好  Chinese (gb2312)",
            "gb2312 character is successfully reassembled",
        );
    } [(qr/DecodeMIMEWordsTo.*?called without field name/i) x 2];
}

diag "multiple mime words containing special chars already in quotes";
{
    my $str = q{attachment; filename="=?ISO-2022-JP?B?Mi4bJEIlSyVlITwlOSVqJWohPCU5GyhC?= =?ISO-2022-JP?B?LnBkZg==?="};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="2.ニュースリリース.pdf"},
        "base64"
    );

    $str = q{attachment; filename="=?UTF-8?Q?2=2E=E3=83=8B=E3=83=A5=E3=83=BC=E3=82=B9=E3=83=AA=E3=83=AA?= =?UTF-8?Q?=E3=83=BC=E3=82=B9=2Epdf?="};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="2.ニュースリリース.pdf"},
        "QP"
    );
}

diag "mime word combined with text in quoted filename property";
{
    my $str = q{attachment; filename="=?UTF-8?B?Q2VjaSBuJ2VzdCBwYXMgdW5l?= pipe.pdf"};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="Ceci n'est pas une pipe.pdf"},
        "base64"
    );

    $str = q{attachment; filename="=?UTF-8?B?Q2VjaSBuJ2VzdCBwYXMgdW5lLi4u?= pipe.pdf"};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="Ceci n'est pas une... pipe.pdf"},
        "base64"
    );

    $str = q{attachment; filename="=?UTF-8?Q?Ceci n'est pas une?= pipe.pdf"};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="Ceci n'est pas une pipe.pdf"},
        "QP"
    );

    $str = q{attachment; filename="=?UTF-8?Q?Ceci n'est pas une...?= pipe.pdf"};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="Ceci n'est pas une... pipe.pdf"},
        "QP"
    );
}

diag "quotes in filename";
{
    my $str = q{attachment; filename="=?UTF-8?B?YSAicXVvdGVkIiBmaWxl?="};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, 'Content-Disposition'),
        q{attachment; filename="a \"quoted\" file"},
        "quoted filename correctly decoded"
    );
}

diag "Alternating encoded-words and not, space is preserved";
{
    my $str = q{A =?UTF-8?Q?B?= C =?UTF-8?Q?D?= E =?UTF-8?Q?F?= G};
    is_string(
        RT::I18N::DecodeMIMEWordsToUTF8($str, "Subject"),
        q{A B C D E F G},
        "Space is preserved between encoded-words and not"
    );
}

done_testing;
