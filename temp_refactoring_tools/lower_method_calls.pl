#!/usr/bin/perl

use strict;
use warnings;

# lowers ->CamelCase
# find lib/ -type f | xargs perl -i -n temp_refactoring_tools/lower_method_calls.pl

my %bad = map { $_ => 1 } qw(
    uploadInfo
    getChild removeChild addChild insertSibling getParent getIndex
    getNodeValue setNodeValue getAllChildren isRoot isLeaf getDepth
    DESTROY
);

my $call_re = qr{(?<=->)([a-zA-Z_]*?[A-Z][a-z][a-zA-Z_]*)\b(?!\w)};

while (<>) {
    s/$call_re/low_api($1)/ge;
    print;
}

sub low_api {
    my $v = shift;
    return $v if $bad{$v};
    $v =~ s/(?<=[a-z])(?=[A-Z])/_/g;
    return lc $v;
}

