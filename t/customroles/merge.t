use strict;
use warnings;

use RT::Test tests => undef;

my $general = RT::Test->load_or_create_queue( Name => 'General' );

my $linus = RT::Test->load_or_create_user( EmailAddress => 'linus@example.com' );
my $blake = RT::Test->load_or_create_user( EmailAddress => 'blake@example.com' );
my $williamson = RT::Test->load_or_create_user( EmailAddress => 'williamson@example.com' );

diag 'create tickets' if $ENV{'TEST_VERBOSE'};
my ($t1, $t2);
{
    $t1 = RT::Test->create_ticket( Queue => 'General', Subject => 'alpha' );
    ok($t1->Id);
    $t2 = RT::Test->create_ticket( Queue => 'General', Subject => 'beta' );
    ok($t2->Id);
}

diag 'create a multi-member role' if $ENV{'TEST_VERBOSE'};
my $multi;
{
    $multi = RT::CustomRole->new(RT->SystemUser);
    my ($ok, $msg) = $multi->Create(
        Name      => 'Multi-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created role: $msg");

    ($ok, $msg) = $multi->AddToObject($general->id);
    ok($ok, "added role to General: $msg");
}

diag 'create a single-member role' if $ENV{'TEST_VERBOSE'};
my $single;
{
    $single = RT::CustomRole->new(RT->SystemUser);
    my ($ok, $msg) = $single->Create(
        Name      => 'Single-' . $$,
        MaxValues => 1,
    );
    ok($ok, "created role: $msg");

    ($ok, $msg) = $single->AddToObject($general->id);
    ok($ok, "added role to General: $msg");
}

diag 'merge tickets [issues.bestpractical.com #32490]' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $t2->MergeInto($t1->Id);
    ok($ok, $msg);

    is($t1->RoleAddresses($multi->GroupType), '', 'no multi members');
    is($t1->RoleAddresses($single->GroupType), '', 'no single members');
}

diag 'create tickets specifying roles' if $ENV{'TEST_VERBOSE'};
my ($t3, $t4);
{
    $t3 = RT::Test->create_ticket(
        Queue => 'General',
        Subject => 'gamma',
        $multi->GroupType => [$linus->EmailAddress],
        $single->GroupType => $linus,
    );
    ok($t3->Id);

    $t4 = RT::Test->create_ticket(
        Queue => 'General',
        Subject => 'gamma',
        $multi->GroupType => [$blake->EmailAddress, $williamson->EmailAddress],
        $single->GroupType => $blake,
    );
    ok($t4->Id);
}

diag 'merge tickets' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $t4->MergeInto($t3->Id);
    ok($ok, $msg);

    is($t3->RoleAddresses($multi->GroupType), (join ', ', sort $blake->EmailAddress, $linus->EmailAddress, $williamson->EmailAddress), 'merged all multi-member addresses');
    is($t3->RoleAddresses($single->GroupType), $linus->EmailAddress, 'took single-member address from merged-into ticket')
}

done_testing;

