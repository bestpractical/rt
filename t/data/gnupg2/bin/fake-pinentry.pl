#!/usr/bin/perl -w
# Use this for your test suites when a perl interpreter is available.
#
# The encrypted keys in your test suite that you expect to work must
# be locked with a passphrase of "test"
#
# Author: Daniel Kahn Gillmor <dkg@fifthhorseman.net>
#
# License: This trivial work is hereby explicitly placed into the
# public domain.  Anyone may reuse it, modify it, redistribute it for
# any purpose.

use strict;
use warnings;
#use File::Basename;
#my $dirname = dirname($0);

#open (my $fh, '<', '/home/user/projects/rt/t/data/gnupg2/bin/passphrase') or die "Cannot open passphrase file: $!";
#my $passphrase = <$fh>;
#chomp $passphrase;
#close $fh;

# turn off buffering
$| = 1;

my $passphrase = 'test';

print "OK This is only for test suites, and should never be used in production\n";
while (<STDIN>) {
  chomp;
  next if (/^$/);
  next if (/^#/);
  print ("D $passphrase\n") if (/^getpin/i);
  #print ("D \n") if (/^getpin/i);
  print "OK\n";
  exit if (/^bye/i);
}
1;
