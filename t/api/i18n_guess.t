#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 9;

use Encode qw(encode);

use constant HAS_ENCODE_GUESS => do { local $@; eval { require Encode::Guess; 1 } };
use constant HAS_ENCODE_DETECT => do { local $@; eval { require Encode::Detect::Detector; 1 } };

my $string = "\x{442}\x{435}\x{441}\x{442} \x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

sub guess {
    is( RT::I18N::_GuessCharset( Encode::encode($_[0], $_[1]) ), $_[0], 'correct guess' );
}

RT->Config->Set(EmailInputEncodings => qw(*));
SKIP: {
    skip "No Encode::Detect", 3 unless HAS_ENCODE_DETECT;
    guess('utf-8', $string);
    guess('cp1251', $string);
    guess('koi8-r', $string);
}

RT->Config->Set(EmailInputEncodings => qw(UTF-8 cp1251 koi8-r));
SKIP: {
    skip "No Encode::Guess", 3 unless HAS_ENCODE_GUESS;
    guess('utf-8', $string);
    {
        local $TODO = 'Encode::Guess can not distinguish cp1251 from koi8-r';
        # we can not todo one test here as it's depends on hash order and
        # varies from system to system
        guess('cp1251', $string);
        guess('koi8-r', $string);
    }
}

RT->Config->Set(EmailInputEncodings => qw(* UTF-8 cp1251 koi8-r));
SKIP: {
    skip "No Encode::Detect", 3 unless HAS_ENCODE_DETECT;
    guess('utf-8', $string);
    guess('cp1251', $string);
    guess('koi8-r', $string);
}

