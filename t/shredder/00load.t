use strict;
use warnings;
use RT::Test nodb => 1, tests => 11;

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

