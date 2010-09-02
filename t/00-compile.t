
use strict;
use warnings;

use RT::Test nodb => 1, tests => 31;

require_ok("RT");
require_ok("RT::Test");
require_ok("RT::ACL");
require_ok("RT::Handle");
require_ok("RT::Transaction");
require_ok("RT::Interface::CLI");
require_ok("RT::Interface::Email");
require_ok("RT::Links");
require_ok("RT::Queues");
require_ok("RT::Scrips");
require_ok("RT::Templates");
require_ok("RT::Principals");
require_ok("RT::Attachments");
require_ok("RT::GroupMember");
require_ok("RT::ScripAction");
require_ok("RT::CustomFields");
require_ok("RT::GroupMembers");
require_ok("RT::ScripActions");
require_ok("RT::Transactions");
require_ok("RT::ScripCondition");
require_ok("RT::Action");
require_ok("RT::ScripConditions");
require_ok("RT::Search");
require_ok("RT::Action::SendEmail");
require_ok("RT::CachedGroupMembers");
require_ok("RT::Condition");
require_ok("RT::Interface::Web");
require_ok("RT::SavedSearch");
require_ok("RT::SavedSearches");
require_ok("RT::Installer");
require_ok("RT::Util");


# no the following doesn't work yet
__END__
use File::Find::Rule;

my @files = File::Find::Rule->file()
    ->name( '*.pm' )
    ->in( 'lib' );

plan tests => scalar @files;

for (@files) {
    local $SIG{__WARN__} = sub {};
    require_ok($_);
}

