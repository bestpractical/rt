use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $general = create_catalog( Name => 'General' );
my $inbox = create_catalog( Name => 'Inbox' );
my $specs = create_catalog( Name => 'Specs' );
my $development = create_catalog( Name => 'Development' );

my $engineer = RT::CustomRole->new(RT->SystemUser);
my $sales = RT::CustomRole->new(RT->SystemUser);
my $unapplied = RT::CustomRole->new(RT->SystemUser);

my $linus = RT::Test->load_or_create_user( EmailAddress => 'linus@example.com' );
my $blake = RT::Test->load_or_create_user( EmailAddress => 'blake@example.com' );
my $williamson = RT::Test->load_or_create_user( EmailAddress => 'williamson@example.com' );
my $moss = RT::Test->load_or_create_user( EmailAddress => 'moss@example.com' );
my $ricky = RT::Test->load_or_create_user( EmailAddress => 'ricky.roma@example.com' );

my $team = RT::Test->load_or_create_group(
    'Team',
    Members => [$blake, $williamson, $moss, $ricky],
);

sub txn_messages_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $a = shift;
    my $re = shift;

    my $txns = $a->Transactions;
    $txns->Limit(FIELD => 'Type', VALUE => 'SetWatcher');
    $txns->Limit(FIELD => 'Type', VALUE => 'AddWatcher');
    $txns->Limit(FIELD => 'Type', VALUE => 'DelWatcher');

    is($txns->Count, scalar(@$re), 'expected number of transactions');

    while (my $txn = $txns->Next) {
        like($txn->BriefDescription, (shift(@$re) || qr/(?!)/));
    }
}

diag 'setup' if $ENV{'TEST_VERBOSE'};
{
    ok( RT::Test->add_rights( { Principal => 'Privileged', Right => [ qw(CreateAsset ShowAsset ModifyAsset ShowCatalog) ] } ));

    my ($ok, $msg) = $engineer->Create(
        Name       => 'Engineer-' . $$,
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok($ok, "created Engineer role: $msg");

    ($ok, $msg) = $sales->Create(
        Name       => 'Sales-' . $$,
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 0,
    );
    ok($ok, "created Sales role: $msg");

    ($ok, $msg) = $unapplied->Create(
        Name       => 'Unapplied-' . $$,
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 0,
    );
    ok($ok, "created Unapplied role: $msg");

    ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "added Sales to Inbox: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($development->id);
    ok($ok, "added Engineer to Development: $msg");
}

diag 'create assets in General (no custom roles)' if $ENV{'TEST_VERBOSE'};
{
    my $general1 = create_asset(
        Catalog   => 'General',
        Name      => 'an asset',
        Owner     => $williamson->PrincipalId,
        Contact   => [$blake->EmailAddress],
    );
    is($general1->Owner->id, $williamson->id, 'owner is correct');
    is($general1->RoleAddresses('Contact'), $blake->EmailAddress, 'contacts correct');
    is($general1->RoleAddresses('HeldBy'), '', 'no heldby');
    is($general1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($general1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $general2 = create_asset(
        Catalog   => 'General',
        Name      => 'another asset',
        Owner     => $linus->PrincipalId,
        Contact   => [$moss->EmailAddress, $williamson->EmailAddress],
        HeldBy    => [$blake->EmailAddress],
    );
    is($general2->Owner->id, $linus->id, 'owner is correct');
    is($general2->RoleAddresses('Contact'), (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'contacts correct');
    is($general2->RoleAddresses('HeldBy'), $blake->EmailAddress, 'heldby correct');
    is($general2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($general2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $general3 = create_asset(
        Catalog              => 'General',
        Name                 => 'oops',
        Owner                => $ricky->PrincipalId,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($general3->Owner->id, $ricky->id, 'owner is correct');
    is($general3->RoleAddresses('Contact'), '', 'no contacts');
    is($general3->RoleAddresses('HeldBy'), '', 'no heldby');
    is($general3->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($general3->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');
}

diag 'create assets in Inbox (sales role)' if $ENV{'TEST_VERBOSE'};
{
    my $inbox1 = create_asset(
        Catalog   => 'Inbox',
        Name      => 'an asset',
        Owner     => $williamson->PrincipalId,
        Contact   => [$blake->EmailAddress],
    );
    is($inbox1->Owner->id, $williamson->id, 'owner is correct');
    is($inbox1->RoleAddresses('Contact'), $blake->EmailAddress, 'contacts correct');
    is($inbox1->RoleAddresses('HeldBy'), '', 'no heldby');
    is($inbox1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($inbox1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $inbox2 = create_asset(
        Catalog   => 'Inbox',
        Name      => 'another asset',
        Owner     => $linus->PrincipalId,
        Contact   => [$moss->EmailAddress, $williamson->EmailAddress],
        HeldBy    => [$blake->EmailAddress],
    );
    is($inbox2->Owner->id, $linus->id, 'owner is correct');
    is($inbox2->RoleAddresses('Contact'), (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'contacts correct');
    is($inbox2->RoleAddresses('HeldBy'), $blake->EmailAddress, 'heldby correct');
    is($inbox2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($inbox2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $inbox3 = create_asset(
        Catalog              => 'Inbox',
        Name                 => 'oops',
        Owner                => $ricky->PrincipalId,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($inbox3->Owner->id, $ricky->id, 'owner is correct');
    is($inbox3->RoleAddresses('Contact'), '', 'no contacts');
    is($inbox3->RoleAddresses('HeldBy'), '', 'no heldby');
    is($inbox3->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($inbox3->RoleAddresses($sales->GroupType), $blake->EmailAddress, 'got sales');

    my $inbox4 = create_asset(
        Catalog              => 'Inbox',
        Name                 => 'more',
        Owner                => $ricky->PrincipalId,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
    );
    is($inbox4->Owner->id, $ricky->id, 'owner is correct');
    is($inbox4->RoleAddresses('Contact'), '', 'no contacts');
    is($inbox4->RoleAddresses('HeldBy'), '', 'no heldby');
    is($inbox4->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($inbox4->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $williamson->EmailAddress), 'got sales');
}

diag 'create assets in Specs (both roles)' if $ENV{'TEST_VERBOSE'};
{
    my $specs1 = create_asset(
        Catalog   => 'Specs',
        Name      => 'an asset',
        Owner     => $williamson->PrincipalId,
        Contact   => [$blake->EmailAddress],
    );
    is($specs1->Owner->id, $williamson->id, 'owner is correct');
    is($specs1->RoleAddresses('Contact'), $blake->EmailAddress, 'contacts correct');
    is($specs1->RoleAddresses('HeldBy'), '', 'no heldby');
    is($specs1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($specs1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $specs2 = create_asset(
        Catalog   => 'Specs',
        Name      => 'another asset',
        Owner     => $linus->PrincipalId,
        Contact   => [$moss->EmailAddress, $williamson->EmailAddress],
        HeldBy    => [$blake->EmailAddress],
    );
    is($specs2->Owner->id, $linus->id, 'owner is correct');
    is($specs2->RoleAddresses('Contact'), (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'contacts correct');
    is($specs2->RoleAddresses('HeldBy'), $blake->EmailAddress, 'heldby correct');
    is($specs2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to catalog)');
    is($specs2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to catalog)');

    my $specs3 = create_asset(
        Catalog              => 'Specs',
        Name                 => 'oops',
        Owner                => $ricky->PrincipalId,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($specs3->Owner->id, $ricky->id, 'owner is correct');
    is($specs3->RoleAddresses('Contact'), '', 'no contacts');
    is($specs3->RoleAddresses('HeldBy'), '', 'no heldby');
    is($specs3->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'got engineer');
    is($specs3->RoleAddresses($sales->GroupType), $blake->EmailAddress, 'got sales');

    my $specs4 = create_asset(
        Catalog              => 'Specs',
        Name                 => 'more',
        Owner                => $ricky->PrincipalId,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
    );
    is($specs4->Owner->id, $ricky->id, 'owner is correct');
    is($specs4->RoleAddresses('Contact'), '', 'no contacts');
    is($specs4->RoleAddresses('HeldBy'), '', 'no heldby');
    is($specs4->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'got engineer');
    is($specs4->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $williamson->EmailAddress), 'got sales');
}

diag 'update asset in Specs' if $ENV{'TEST_VERBOSE'};
{
    my $a = create_asset(
        Catalog => 'Specs',
        Name    => 'updates',
    );

    is($a->Owner->id, RT->Nobody->id, 'owner nobody');
    is($a->RoleAddresses('Contact'), '', 'no contacts');
    is($a->RoleAddresses('HeldBy'), '', 'no heldby');
    is($a->RoleAddresses($engineer->GroupType), '', 'no engineer');
    is($a->RoleAddresses($sales->GroupType), '', 'no sales');
    is($a->RoleAddresses($unapplied->GroupType), '', 'no unapplied');

    my ($ok, $msg) = $a->AddRoleMember(Type => 'Owner', Principal => $linus->PrincipalObj);
    ok($ok, "set owner: $msg");
    is($a->Owner->id, $linus->id, 'owner linus');

    ($ok, $msg) = $a->AddRoleMember(Type => 'Contact', Principal => $ricky->PrincipalObj);
    ok($ok, "add contact: $msg");
    is($a->RoleAddresses('Contact'), $ricky->EmailAddress, 'contact ricky');

    ($ok, $msg) = $a->AddRoleMember(Type => 'HeldBy', Principal => $blake->PrincipalObj);
    ok($ok, "add heldby: $msg");
    is($a->RoleAddresses('HeldBy'), $blake->EmailAddress, 'heldby blake');

    ($ok, $msg) = $a->AddRoleMember(Type => $sales->GroupType, Principal => $ricky->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($a->RoleAddresses($sales->GroupType), $ricky->EmailAddress, 'sales ricky');

    ($ok, $msg) = $a->AddRoleMember(Type => $sales->GroupType, Principal => $moss->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($a->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $a->AddRoleMember(Type => $sales->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($a->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $a->DeleteRoleMember(Type => $sales->GroupType, PrincipalId => $moss->PrincipalId);
    ok($ok, "remove sales: $msg");
    is($a->RoleAddresses($sales->GroupType), $ricky->EmailAddress, 'sales ricky');

    ($ok, $msg) = $a->DeleteRoleMember(Type => $sales->GroupType, PrincipalId => $ricky->PrincipalId);
    ok($ok, "remove sales: $msg");
    is($a->RoleAddresses($sales->GroupType), '', 'sales empty');

    ($ok, $msg) = $a->AddRoleMember(Type => $engineer->GroupType, Principal => $linus->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($a->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'engineer linus');

    ($ok, $msg) = $a->AddRoleMember(Type => $engineer->GroupType, Principal => $blake->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($a->RoleAddresses($engineer->GroupType), $blake->EmailAddress, 'engineer blake (single-member role so linus gets displaced)');

    ($ok, $msg) = $a->AddRoleMember(Type => $engineer->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($a->RoleAddresses($engineer->GroupType), '', 'engineer nobody (single-member role so blake gets displaced)');

    ($ok, $msg) = $a->AddRoleMember(Type => $unapplied->GroupType, Principal => $linus->PrincipalObj);
    ok(!$ok, "did not add unapplied role member: $msg");
    like($msg, qr/That role is invalid for this object/);
    is($a->RoleAddresses($unapplied->GroupType), '', 'no unapplied members');

    txn_messages_like($a, [
        qr/Owner set to linus\@example\.com/,
        qr/Contact ricky\.roma\@example\.com added/,
        qr/Held By blake\@example\.com added/,
        qr/Sales-$$ ricky\.roma\@example\.com added/,
        qr/Sales-$$ moss\@example\.com added/,
        qr/Sales-$$ Nobody in particular added/,
        qr/Sales-$$ moss\@example\.com deleted/,
        qr/Sales-$$ ricky\.roma\@example\.com deleted/,
        qr/Engineer-$$ set to linus\@example\.com/,
        qr/Engineer-$$ set to blake\@example\.com/,
        qr/Engineer-$$ set to Nobody in particular/,
    ]);
}

diag 'groups can be role members' if $ENV{'TEST_VERBOSE'};
{
    my $a = create_asset(
        Catalog => 'Specs',
        Name    => 'groups',
    );

    my ($ok, $msg) = $a->AddRoleMember(Type => $sales->GroupType, Principal => $team->PrincipalObj);
    ok($ok, "add team: $msg");
    is($a->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $ricky->EmailAddress, $moss->EmailAddress, $williamson->EmailAddress), 'sales is all the team members');

    ($ok, $msg) = $a->AddRoleMember(Type => $engineer->GroupType, Principal => $team->PrincipalObj);
    ok(!$ok, "could not add team: $msg");
    like($msg, qr/cannot be a group/);
    is($a->RoleAddresses($engineer->GroupType), '', 'engineer is still nobody');

    txn_messages_like($a, [
        qr/Sales-$$ group Team added/,
    ]);
}

done_testing;
