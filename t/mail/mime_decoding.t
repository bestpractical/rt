#!/usr/bin/perl
use strict;
use warnings;
use RT::Test nodb => 1, tests => 9;

use_ok('RT::I18N');

diag q{'=' char in a leading part before an encoded part};
{
    my $str = 'key="plain"; key="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'key="plain"; key="мой_файл.bin"',
        "right decoding"
    );
}

diag q{not compliant with standards, but MUAs send such field when attachment has non-ascii in name};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'attachment; filename="мой_файл.bin"',
        "right decoding"
    );
}

diag q{'=' char in a trailing part after an encoded part};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="; some_prop="value"';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'attachment; filename="мой_файл.bin"; some_prop="value"',
        "right decoding"
    );
}

diag q{regression test for #5248 from rt3.fsck.com};
{
    my $str = qq{Subject: =?ISO-8859-1?Q?Re=3A_=5BXXXXXX=23269=5D_=5BComment=5D_Frag?=}
        . qq{\n =?ISO-8859-1?Q?e_zu_XXXXXX--xxxxxx_/_Xxxxx=FCxxxxxxxxxx?=};
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        qq{Subject: Re: [XXXXXX#269] [Comment] Frage zu XXXXXX--xxxxxx / Xxxxxüxxxxxxxxxx},
        "right decoding"
    );
}

diag q{newline and encoded file name};
{
    my $str = qq{application/vnd.ms-powerpoint;\n\tname="=?ISO-8859-1?Q?Main_presentation.ppt?="};
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        qq{application/vnd.ms-powerpoint;\tname="Main presentation.ppt"},
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
	=?gb2312?B?dHRhY2hlbWVudCB0ZXN0IGluIENOIHNpbXBsaWZpZWQ=?=};

    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        qq{Subject: 在世界各地共有超過_Simplified_CN_GB2312attachement test in CN simplified},
        "right decoding"
    );
}

