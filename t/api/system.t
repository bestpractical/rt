
use strict;
use warnings;
use RT;
use RT::Test nodata => 1, tests => 16;

BEGIN{
  use_ok('RT::System');
}

# Skipping most of the methods added just to make RT::System
# look like RT::Record.

can_ok('RT::System', qw( AvailableRights RightCategories AddRight
                         id Id SubjectTag Name QueueCacheNeedsUpdate AddUpgradeHistory
                         UpgradeHistory ));

{

my $s = RT::System->new(RT->SystemUser);
my $rights = $s->AvailableRights;
ok ($rights, "Rights defined");
ok ($rights->{'AdminUsers'},"AdminUsers right found");
ok ($rights->{'CreateTicket'},"CreateTicket right found");
ok ($rights->{'AdminGroupMembership'},"ModifyGroupMembers right found");
ok (!$rights->{'CasdasdsreateTicket'},"bogus right not found");

}

{

my $sys = RT::System->new();
is( $sys->Id, 1, 'Id is 1');
is ($sys->id, 1, 'id is 1');

}

{

# Test upgrade history methods.

my $sys = RT::System->new(RT->SystemUser);
isa_ok($sys, 'RT::System');

my $file = 'test_file.txt';
my $content = 'Some file contents.';
my $upgrade_history = RT->System->UpgradeHistory();

is( keys %$upgrade_history, 0, 'No history in test DB');

RT->System->AddUpgradeHistory(RT =>{
        action   => 'insert',
        filename => $file,
        content  => $content,
        stage    => 'before',
    });

$upgrade_history = RT->System->UpgradeHistory();
ok( exists($upgrade_history->{'RT'}), 'History has an RT key.');
is( @{$upgrade_history->{'RT'}}, 1, '1 item in history array');
is($upgrade_history->{RT}[0]{stage}, 'before', 'stage is before for item 1');

RT->System->AddUpgradeHistory(RT =>{
        action   => 'insert',
        filename => $file,
        content  => $content,
        stage    => 'after',
    });

$upgrade_history = RT->System->UpgradeHistory();
is( @{$upgrade_history->{'RT'}}, 2, '2 item in history array');
is($upgrade_history->{RT}[1]{stage}, 'after', 'stage is after for item 2');

}
