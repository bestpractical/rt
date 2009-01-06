#!/usr/bin/perl -w
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
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
