#!/usr/bin/perl -w
use strict;
use LWP::Simple 'getstore';
use Archive::Extract;
use File::Temp;
use File::Copy 'copy';

my $url = shift or die 'must provide rosseta download url';

my $dir = File::Temp::tempdir;
my ($fname) = $url =~ m{([^/]+)$};
print "Downloading $url\n";
getstore($url => "$dir/$fname");
print "Extracting $dir/$fname\n";
my $ae = Archive::Extract->new(archive => "$dir/$fname");
my $ok = $ae->extract( to => $dir );

for (<$dir/rt/*.po>) {
    my ($name) = m/([\w_]+)\.po/;
    my $fname = "lib/RT/I18N/$name";

    print "$_ -> $fname.po\n";
    copy($_ => "$fname.po");
}

print "Merging new strings\n";
system("$^X sbin/extract-message-catalog");
