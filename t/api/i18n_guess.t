
use strict;
use warnings;

use RT::Test tests => 16;

use constant HAS_ENCODE_GUESS => Encode::Guess->require;
use constant HAS_ENCODE_DETECT => Encode::Detect::Detector->require;

my $string = "\x{442}\x{435}\x{441}\x{442} \x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

sub guess {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is( RT::I18N::_GuessCharset( Encode::encode($_[0], $_[1]) ), $_[2] || $_[0], "$_[0] guesses as @{[$_[2]||$_[0]]}" );
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
    skip "No Encode::Guess", 4 unless HAS_ENCODE_GUESS;
    guess('utf-8', $string);
    guess('cp1251', $string);
    guess('windows-1251', $string, 'cp1251');
    {
        local $TODO = "Encode::Guess can't distinguish cp1251 from koi8-r";
        guess('koi8-r', $string);
    }
}

RT->Config->Set(EmailInputEncodings => qw(UTF-8 koi8-r cp1251));
SKIP: {
    skip "No Encode::Guess", 3 unless HAS_ENCODE_GUESS;
    guess('utf-8', $string);
    guess('koi8-r', $string);
    {
        local $TODO = "Encode::Guess can't distinguish cp1251 from koi8-r";
        guess('cp1251', $string);
    }
}

# windows-1251 is an alias for cp1251, post load check cleanups array for us
RT->Config->Set(EmailInputEncodings => qw(UTF-8 windows-1251 koi8-r));
RT->Config->PostLoadCheck;
SKIP: {
    skip "No Encode::Guess", 3 unless HAS_ENCODE_GUESS;
    guess('utf-8', $string);
    guess('cp1251', $string);
    {
        local $TODO = "Encode::Guess can't distinguish cp1251 from koi8-r";
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

