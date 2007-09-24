
use strict;
use warnings;
use RT::Test; use Test::More tests => 31;

require_ok("RT");
require_ok("RT::Test");
require_ok("RT::Model::ACECollection");
require_ok("RT::Model::Transaction");
require_ok("RT::Interface::CLI");
require_ok("RT::Interface::Email");
require_ok("RT::Model::LinkCollection");
require_ok("RT::Model::QueueCollection");
require_ok("RT::Model::ScripCollection");
require_ok("RT::Model::TemplateCollection");
require_ok("RT::Model::PrincipalCollection");
require_ok("RT::Model::AttachmentCollection");
require_ok("RT::Model::GroupMember");
require_ok("RT::Model::ScripAction");
require_ok("RT::Model::CustomFieldCollection");
require_ok("RT::Model::GroupMemberCollection");
require_ok("RT::Model::ScripActionCollection");
require_ok("RT::Model::TransactionCollection");
require_ok("RT::Model::ScripCondition");
require_ok("RT::ScripAction::Generic");
require_ok("RT::Model::ScripConditionCollection");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::Search::Generic");
require_ok("RT::ScripAction::SendEmail");
require_ok("RT::Model::CachedGroupMemberCollection");
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
