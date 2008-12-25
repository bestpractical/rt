#!/usr/bin/perl -w
use strict;
use LWP::Simple 'getstore';
use Locale::PO;
use Locale::Maketext::Extract;
use Archive::Extract;
use File::Temp;
use File::Copy 'copy';

my $url = shift or die 'must provide rosseta download url or directory';

my $dir;

if ($url =~ m/http/) {
    $dir = File::Temp::tempdir;
    my ($fname) = $url =~ m{([^/]+)$};
    print "Downloading $url\n";
    getstore($url => "$dir/$fname");
    print "Extracting $dir/$fname\n";
    my $ae = Archive::Extract->new(archive => "$dir/$fname");
    my $ok = $ae->extract( to => $dir );
}
else {
    $dir = $url;
}

Locale::Maketext::Lexicon::set_option('use_fuzzy', 1);
Locale::Maketext::Lexicon::set_option('allow_empty', 1);

for (<$dir/rt/*.po>) {
    my ($name) = m/([\w_]+)\.po/;
    my $fname = "lib/RT/I18N/$name";
    my $tmp = File::Temp->new;

    print "$_ -> $fname.po\n";

    # retain the "NOT FOUND IN SOURCE" entries
    system("sed -e 's/^#~ //' $_ > $tmp");
    my $ext = Locale::Maketext::Extract->new;
    $ext->read_po($tmp);

    my $po_orig = Locale::PO->load_file_ashash("$fname.po");
    # don't want empty vales to override ours.
    # don't want fuzzy flag as when uploading to rosetta again it's not accepted by rosetta.
    foreach my $msgid ($ext->msgids) {
        my $entry = $po_orig->{Locale::PO->quote($msgid)} or next;
        my $msgstr = $entry->dequote($entry->{msgstr}) or next;
        $ext->set_msgstr($msgid, $msgstr)
            if $ext->msgstr($msgid) eq '' && $msgstr;
    }
    $ext->write_po("$fname.po");
}

print "Merging new strings\n";
system("$^X sbin/extract-message-catalog");
