#!/usr/bin/perl
use strict;
use warnings;
use RT::Test nodb => 1, tests => 8;

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
"filename*=ISO-8859-1''%74%E9%73%74%2E%74%78%74 filename*=ISO-8859-1''%74%E9%73%74%2E%74%78%74";
    is(
        RT::I18N::DecodeMIMEWordsToEncoding( $str, 'utf-8' ),
        'filename=tést.txt filename=tést.txt',
        'right decodig'
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

