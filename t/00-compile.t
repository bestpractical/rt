
use strict;
use warnings;
use Carp::REPL;
use RT::Test nodata => 1;
use Test::More tests => 32;

require_ok("RT");
require_ok("RT::Test");
require_ok("RT::Model::ACL");
require_ok("RT::Handle");
require_ok("RT::Model::Transaction");
require_ok("RT::Interface::CLI");
require_ok("RT::Interface::Email");
require_ok("RT::Model::Links");
require_ok("RT::Model::Queues");
require_ok("RT::Model::Scrips");
require_ok("RT::Model::Templates");
require_ok("RT::Model::Principals");
require_ok("RT::Model::Attachments");
require_ok("RT::Model::GroupMember");
require_ok("RT::Model::ScripAction");
require_ok("RT::Model::CustomFields");
require_ok("RT::Model::GroupMembers");
require_ok("RT::Model::ScripActions");
require_ok("RT::Model::Transactions");
require_ok("RT::Model::ScripCondition");
require_ok("RT::Action::Generic");
require_ok("RT::Model::ScripConditions");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::Action::SendEmail");
require_ok("RT::Model::CachedGroupMembers");
require_ok("RT::Condition::Generic");
require_ok("RT::Interface::Web");
require_ok("RT::SavedSearch");
require_ok("RT::SavedSearches");


# no the following doesn't work yet
__END__
use File::Find::Rule;

my @files = File::Find::Rule->file()
    ->name( '*.pm' )
    ->in( 'lib' );

plan tests => scalar @files;

for (@files) {
    require_ok($_);
    diag $_;
}

1;
