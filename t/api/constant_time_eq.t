use utf8;
use warnings;
use strict;
use RT;
use RT::Test tests => undef;
use Test::Exception;

use_ok "RT::Util";

my ($a, $b) = (1, 2);

# die-worthy error conditions
_dies_ok (eval { RT::Util::constant_time_eq(undef, undef) }, 'Should die: both args undefined');
_dies_ok (eval { RT::Util::constant_time_eq('', undef)    }, 'Should die: first arg undefined');
_dies_ok (eval { RT::Util::constant_time_eq(undef, '')    }, 'Should die: second arg undefined');
_dies_ok (eval { RT::Util::constant_time_eq('', 'a')      }, 'Should die: empty string and non-empty string (different length)');
_dies_ok (eval { RT::Util::constant_time_eq('a', '')      }, 'Should die: empty string and non-empty string (different length)');
_dies_ok (eval { RT::Util::constant_time_eq('abcde', 'abcdef')    }, 'strings different lengths should die');
_dies_ok (eval { RT::Util::constant_time_eq('ff', 'ﬀ')    }, 'string "ff" and ligature "ﬀ" should die (different lengths)');
_dies_ok (eval { RT::Util::constant_time_eq(\$a, '')      }, 'First arg ref should die');
_dies_ok (eval { RT::Util::constant_time_eq('', \$b)      }, 'Second arg ref should die');
_dies_ok (eval { RT::Util::constant_time_eq(\$a, \$a)     }, 'Both args same ref should die');

# Check unicode chars
_lives_and (eval { RT::Util::constant_time_eq('', '') },       1, 'both args empty strings is true');
_lives_and (eval { RT::Util::constant_time_eq('a', 'a') },     1, 'both args one-byte chars is true');
_lives_and (eval { RT::Util::constant_time_eq('þ', 'þ') },     1, 'both args two-byte utf8 chars is true');
_dies_ok   (eval { RT::Util::constant_time_eq('þ', 'Ã¾') },       'a two-byte utf8 char and its mojibake dies');
_lives_and (eval { RT::Util::constant_time_eq('þ', 'ÿ') },     0, 'two-byte utf8 chars which differ by one bit');
_lives_and (eval { RT::Util::constant_time_eq('þ', '¾') },     0, 'two-byte utf8 chars which differ by one bit');
_lives_and (eval { RT::Util::constant_time_eq('þ', '¿') },     0, 'two-byte utf8 chars which differ by two bits');
_dies_ok   (eval { RT::Util::constant_time_eq('þ', 'xx') },       'two-byte utf8 and two one-byte chars is false');
_lives_and (eval { RT::Util::constant_time_eq('試', '試') },   1, 'both args three-byte utf8 chars is true');
_dies_ok   (eval { RT::Util::constant_time_eq('試', 'xxx') },     'three-byte utf8 and three one-byte chars is false');
_lives_and (eval { RT::Util::constant_time_eq('😎', '😎') },   1, 'both args four-byte utf8 chars is true');
_dies_ok   (eval { RT::Util::constant_time_eq('😎', 'xxxx') },    'four-byte utf8 and four one-byte chars is false');
_lives_and (eval { RT::Util::constant_time_eq('😎✈️'x1024, '😎✈️'x1024) }, 1, 'both long strings of utf8 chars is true');

# Longer strings
_lives_and (eval { RT::Util::constant_time_eq('a'x4096, 'a'x4096) },             1, 'both args equal long strings is true');
_lives_and (eval { RT::Util::constant_time_eq('a'x4096 . 'c', 'a'x4096 . 'b') }, 0, 'both args unequal long strings is false');

# Numeric values would be stringified before comparison. This should never
# be used this way, but if so the behaviour should remain consistent.
_lives_and (eval { RT::Util::constant_time_eq(0, 0) },                 1, 'both args equal zero ints is true');
_lives_and (eval { RT::Util::constant_time_eq(123456789, 123456789) }, 1, 'both args equal long ints is true');
_lives_and (eval { RT::Util::constant_time_eq(123.456, 123.456) },     1, 'both args equal floats is true');
_lives_and (eval { RT::Util::constant_time_eq(0, 1) },                 0, 'both args unequal ints is false');

# Big List of Naughty Strings (https://github.com/minimaxir/big-list-of-naughty-strings)
my $f;
open ($f, '<', 't/data/input/blns.txt') or die "can't open blns.txt";
my $line = 0;
while(<$f>) {
    $line++;
    next if length($_) == 0;
    next if $_ =~ /^#\w/;
    my $string = $_;
    _lives_and (eval { RT::Util::constant_time_eq($string, $string) }, 1, "Big List of Naughty String, blns.txt line $line");
}
close $f;

# TODO: statistical analysis of the timing performance of RT::Util::constant_time_eq
# This is probably very difficult to do and have work across myriad systems that could
# end up running RT. This note serves to remind you to test manually if you change
# the function.

done_testing();

# Helpers inspired by Test::Exception

sub _lives_and {
    my ($t, $r, $message) = @_;
    is ($@, '', $message);
    is ($t, $r, $message);
}

sub _dies_ok {
    my ($t, $message) = @_;
    isnt ($@, '', $message);
}
