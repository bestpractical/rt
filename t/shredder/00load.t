use strict;
use warnings;
use File::Spec;
use Test::More tests => 11;

BEGIN {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    my $shredder_utils = File::Spec->catfile(
        File::Spec->catdir(File::Spec->curdir(), $directories), "utils.pl");
    require $shredder_utils;
}

use_ok("RT::Shredder");

use_ok("RT::Shredder::Plugin");
use_ok("RT::Shredder::Plugin::Base");

# search plugins
use_ok("RT::Shredder::Plugin::Base::Search");
use_ok("RT::Shredder::Plugin::Objects");
use_ok("RT::Shredder::Plugin::Attachments");
use_ok("RT::Shredder::Plugin::Tickets");
use_ok("RT::Shredder::Plugin::Users");

# dump plugins
use_ok("RT::Shredder::Plugin::Base::Dump");
use_ok("RT::Shredder::Plugin::SQLDump");
use_ok("RT::Shredder::Plugin::Summary");

