#!/usr/bin/perl

use strict;
use warnings;

# lowers column => 'CamelCase'
# find lib/ -type f | xargs perl -i -n temp_refactoring_tools/lower_column_args.pl

my %bad = map {$_ => 1} qw();

my $wid_re = qr{([a-zA-Z_]*?[A-Z][a-z][a-zA-Z_]*)\b(?!\w)};

while(<>) {
    s{ (column[12]? \s+ => \s* ') $wid_re (' \s* (,|$))  }{ $1 . low_api($2) . $3 }gxe;
    s{ (column[12]? \s+ => \s* ") $wid_re (" \s* (,|$))  }{ $1 . low_api($2) . $3 }gxe;
    print;
}

sub low_api {
    my $v = shift;
    return $v if $bad{ $v };
    $v =~ s/(?<=[a-z])(?=[A-Z])/_/g;
    return lc $v;
}

