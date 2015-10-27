use strict;
use warnings;

use RT::Test tests => undef;

my $specs = RT::Test->load_or_create_queue( Name => 'Specs' );

my $engineer = RT::CustomRole->new(RT->SystemUser);
my $sales = RT::CustomRole->new(RT->SystemUser);
my $unapplied = RT::CustomRole->new(RT->SystemUser);

my $linus = RT::Test->load_or_create_user( EmailAddress => 'linus@example.com' );
my $blake = RT::Test->load_or_create_user( EmailAddress => 'blake@example.com' );
my $williamson = RT::Test->load_or_create_user( EmailAddress => 'williamson@example.com' );
my $moss = RT::Test->load_or_create_user( EmailAddress => 'moss@example.com' );
my $ricky = RT::Test->load_or_create_user( EmailAddress => 'ricky.roma@example.com' );

ok( RT::Test->add_rights( { Principal => 'Privileged', Right => [ qw(CreateTicket ShowTicket ModifyTicket OwnTicket SeeQueue) ] } ));

my $t1 = RT::Test->create_ticket(
    Queue   => $specs,
    Subject => 'updates with a first test pass',
);

my $t2 = RT::Test->create_ticket(
    Queue   => $specs,
    Subject => 'updates without a test pass',
);

my $sales_grouptype = 'RT::CustomRole-1';
my $engineer_grouptype = 'RT::CustomRole-2';
my $unapplied_grouptype = 'RT::CustomRole-3';

diag 'try first pass test' if $ENV{'TEST_VERBOSE'};
{
    is($t1->RoleAddresses($engineer_grouptype), '', 'no engineer');
    is($t1->RoleAddresses($sales_grouptype), '', 'no sales');
    is($t1->RoleAddresses($unapplied_grouptype), '', 'no unapplied');
    ok($t1->RoleGroup($engineer_grouptype), 'has a role group object');
    ok(!$t1->RoleGroup($engineer_grouptype)->id, 'has a role group object with no id');

    my ($ok, $msg) = $t1->AddWatcher(Type => $sales_grouptype, Principal => $ricky->PrincipalObj);
    ok(!$ok, "couldn't add sales: $msg");
    is($t1->RoleAddresses($sales_grouptype), '', 'sales still empty');

    ($ok, $msg) = $t1->AddWatcher(Type => $engineer_grouptype, Principal => $linus->PrincipalObj);
    ok(!$ok, "couldn't add engineer: $msg");
    is($t1->RoleAddresses($engineer_grouptype), '', 'engineer still empty');

    ($ok, $msg) = $t1->AddWatcher(Type => $unapplied_grouptype, Principal => $linus->PrincipalObj);
    ok(!$ok, "couldn't add unapplied: $msg");
    is($t1->RoleAddresses($unapplied_grouptype), '', 'no unapplied members');
}

diag 'create roles and add them to the queue' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $engineer->Create(
        Name      => 'Engineer-' . $$,
        MaxValues => 1,
    );
    ok($ok, "created Engineer role: $msg");

    ($ok, $msg) = $sales->Create(
        Name      => 'Sales-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created Sales role: $msg");

    ($ok, $msg) = $unapplied->Create(
        Name      => 'Unapplied-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created Unapplied role: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");
}

for my $t ($t1, $t2) {
    diag 'test managing watchers of new roles on #' . $t->id if $ENV{'TEST_VERBOSE'};

    my ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => $ricky->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), $ricky->EmailAddress, 'sales ricky');

    ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => $moss->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $linus->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'engineer linus');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $blake->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), $blake->EmailAddress, 'engineer blake (single-member role so linus gets displaced)');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), '', 'engineer nobody (single-member role so blake gets displaced)');

    ($ok, $msg) = $t->AddWatcher(Type => $unapplied->GroupType, Principal => $linus->PrincipalObj);
    ok(!$ok, "did not add unapplied role member: $msg");
    is($t->RoleAddresses($unapplied->GroupType), '', 'no unapplied members');

    ok($t->RoleGroup($sales->GroupType), 'has a Sales group object');
    ok($t->RoleGroup($sales->GroupType)->id, 'has a Sales group object with an id');
    ok($t->RoleGroup($engineer->GroupType), 'has an Engineer group object');
    ok($t->RoleGroup($engineer->GroupType)->id, 'has an Engineer group object with an id');
    ok($t->RoleGroup($unapplied->GroupType), 'has an Unapplied group object');
    ok(!$t->RoleGroup($unapplied->GroupType)->id, 'has an Unapplied group object with no id');
}

done_testing;
