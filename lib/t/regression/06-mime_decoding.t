#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;

use_ok("RT");

RT::LoadConfig();
RT::Init();

use_ok('RT::I18N');

diag q{'=' char in a leading part before an encoded part} if $ENV{TEST_VERBOSE};
{
    my $str = 'key="plain"; key="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'key="plain"; key="мой_файл.bin"',
        "right decoding"
    );
}

diag q{not compliant with standards, but MUAs send such field when attachment has non-ascii in name}
    if $ENV{TEST_VERBOSE};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'attachment; filename="мой_файл.bin"',
        "right decoding"
    );
}

diag q{'=' char in a trailing part after an encoded part} if $ENV{TEST_VERBOSE};
{
    my $str = 'attachment; filename="=?UTF-8?B?0LzQvtC5X9GE0LDQudC7LmJpbg==?="; some_prop="value"';
    is(
        RT::I18N::DecodeMIMEWordsToUTF8($str),
        'attachment; filename="мой_файл.bin"; some_prop="value"',
        "right decoding"
    );
}

