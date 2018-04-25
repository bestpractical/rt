use strict;
use warnings;

use RT::Test tests => undef;

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $inbox = RT::Test->load_or_create_queue( Name => 'Inbox' );
my $specs = RT::Test->load_or_create_queue( Name => 'Specs' );
my $development = RT::Test->load_or_create_queue( Name => 'Development' );

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

    my $t = shift;
    my $re = shift;

    my $txns = $t->Transactions;
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
    ok( RT::Test->add_rights( { Principal => 'Privileged', Right => [ qw(CreateTicket ShowTicket ModifyTicket OwnTicket SeeQueue) ] } ));

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

    ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "added Sales to Inbox: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($development->id);
    ok($ok, "added Engineer to Development: $msg");
}

diag 'create tickets in General (no custom roles)' if $ENV{'TEST_VERBOSE'};
{
    my $general1 = RT::Test->create_ticket(
        Queue     => $general,
        Subject   => 'a ticket',
        Owner     => $williamson,
        Requestor => [$blake->EmailAddress],
    );
    is($general1->OwnerObj->id, $williamson->id, 'owner is correct');
    is($general1->RequestorAddresses, $blake->EmailAddress, 'requestors correct');
    is($general1->CcAddresses, '', 'no ccs');
    is($general1->AdminCcAddresses, '', 'no adminccs');
    is($general1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($general1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $general2 = RT::Test->create_ticket(
        Queue     => $general,
        Subject   => 'another ticket',
        Owner     => $linus,
        Requestor => [$moss->EmailAddress, $williamson->EmailAddress],
        Cc        => [$ricky->EmailAddress],
        AdminCc   => [$blake->EmailAddress],
    );
    is($general2->OwnerObj->id, $linus->id, 'owner is correct');
    is($general2->RequestorAddresses, (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'requestors correct');
    is($general2->CcAddresses, $ricky->EmailAddress, 'cc correct');
    is($general2->AdminCcAddresses, $blake->EmailAddress, 'admincc correct');
    is($general2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($general2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $general3 = RT::Test->create_ticket(
        Queue                => $general,
        Subject              => 'oops',
        Owner                => $ricky,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($general3->OwnerObj->id, $ricky->id, 'owner is correct');
    is($general3->RequestorAddresses, '', 'no requestors');
    is($general3->CcAddresses, '', 'no cc');
    is($general3->AdminCcAddresses, '', 'no admincc');
    is($general3->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($general3->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');
}

diag 'create tickets in Inbox (sales role)' if $ENV{'TEST_VERBOSE'};
{
    my $inbox1 = RT::Test->create_ticket(
        Queue     => $inbox,
        Subject   => 'a ticket',
        Owner     => $williamson,
        Requestor => [$blake->EmailAddress],
    );
    is($inbox1->OwnerObj->id, $williamson->id, 'owner is correct');
    is($inbox1->RequestorAddresses, $blake->EmailAddress, 'requestors correct');
    is($inbox1->CcAddresses, '', 'no ccs');
    is($inbox1->AdminCcAddresses, '', 'no adminccs');
    is($inbox1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($inbox1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $inbox2 = RT::Test->create_ticket(
        Queue     => $inbox,
        Subject   => 'another ticket',
        Owner     => $linus,
        Requestor => [$moss->EmailAddress, $williamson->EmailAddress],
        Cc        => [$ricky->EmailAddress],
        AdminCc   => [$blake->EmailAddress],
    );
    is($inbox2->OwnerObj->id, $linus->id, 'owner is correct');
    is($inbox2->RequestorAddresses, (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'requestors correct');
    is($inbox2->CcAddresses, $ricky->EmailAddress, 'cc correct');
    is($inbox2->AdminCcAddresses, $blake->EmailAddress, 'admincc correct');
    is($inbox2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($inbox2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $inbox3 = RT::Test->create_ticket(
        Queue                => $inbox,
        Subject              => 'oops',
        Owner                => $ricky,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($inbox3->OwnerObj->id, $ricky->id, 'owner is correct');
    is($inbox3->RequestorAddresses, '', 'no requestors');
    is($inbox3->CcAddresses, '', 'no cc');
    is($inbox3->AdminCcAddresses, '', 'no admincc');
    is($inbox3->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($inbox3->RoleAddresses($sales->GroupType), $blake->EmailAddress, 'got sales');

    my $inbox4 = RT::Test->create_ticket(
        Queue                => $inbox,
        Subject              => 'more',
        Owner                => $ricky,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
    );
    is($inbox4->OwnerObj->id, $ricky->id, 'owner is correct');
    is($inbox4->RequestorAddresses, '', 'no requestors');
    is($inbox4->CcAddresses, '', 'no cc');
    is($inbox4->AdminCcAddresses, '', 'no admincc');
    is($inbox4->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($inbox4->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $williamson->EmailAddress), 'got sales');
}

diag 'create tickets in Specs (both roles)' if $ENV{'TEST_VERBOSE'};
{
    my $specs1 = RT::Test->create_ticket(
        Queue     => $specs,
        Subject   => 'a ticket',
        Owner     => $williamson,
        Requestor => [$blake->EmailAddress],
    );
    is($specs1->OwnerObj->id, $williamson->id, 'owner is correct');
    is($specs1->RequestorAddresses, $blake->EmailAddress, 'requestors correct');
    is($specs1->CcAddresses, '', 'no ccs');
    is($specs1->AdminCcAddresses, '', 'no adminccs');
    is($specs1->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($specs1->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $specs2 = RT::Test->create_ticket(
        Queue     => $specs,
        Subject   => 'another ticket',
        Owner     => $linus,
        Requestor => [$moss->EmailAddress, $williamson->EmailAddress],
        Cc        => [$ricky->EmailAddress],
        AdminCc   => [$blake->EmailAddress],
    );
    is($specs2->OwnerObj->id, $linus->id, 'owner is correct');
    is($specs2->RequestorAddresses, (join ', ', sort $moss->EmailAddress, $williamson->EmailAddress), 'requestors correct');
    is($specs2->CcAddresses, $ricky->EmailAddress, 'cc correct');
    is($specs2->AdminCcAddresses, $blake->EmailAddress, 'admincc correct');
    is($specs2->RoleAddresses($engineer->GroupType), '', 'no engineer (role not applied to queue)');
    is($specs2->RoleAddresses($sales->GroupType), '', 'no sales (role not applied to queue)');

    my $specs3 = RT::Test->create_ticket(
        Queue                => $specs,
        Subject              => 'oops',
        Owner                => $ricky,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress],
    );
    is($specs3->OwnerObj->id, $ricky->id, 'owner is correct');
    is($specs3->RequestorAddresses, '', 'no requestors');
    is($specs3->CcAddresses, '', 'no cc');
    is($specs3->AdminCcAddresses, '', 'no admincc');
    is($specs3->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'got engineer');
    is($specs3->RoleAddresses($sales->GroupType), $blake->EmailAddress, 'got sales');

    my $specs4 = RT::Test->create_ticket(
        Queue                => $specs,
        Subject              => 'more',
        Owner                => $ricky,
        $engineer->GroupType => $linus,
        $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
    );
    is($specs4->OwnerObj->id, $ricky->id, 'owner is correct');
    is($specs4->RequestorAddresses, '', 'no requestors');
    is($specs4->CcAddresses, '', 'no cc');
    is($specs4->AdminCcAddresses, '', 'no admincc');
    is($specs4->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'got engineer');
    is($specs4->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $williamson->EmailAddress), 'got sales');
}

diag 'update ticket in Specs' if $ENV{'TEST_VERBOSE'};
{
    my $t = RT::Test->create_ticket(
        Queue   => $specs,
        Subject => 'updates',
    );

    is($t->OwnerObj->id, RT->Nobody->id, 'owner nobody');
    is($t->RequestorAddresses, '', 'no requestors');
    is($t->CcAddresses, '', 'no cc');
    is($t->AdminCcAddresses, '', 'no admincc');
    is($t->RoleAddresses($engineer->GroupType), '', 'no engineer');
    is($t->RoleAddresses($sales->GroupType), '', 'no sales');
    is($t->RoleAddresses($unapplied->GroupType), '', 'no unapplied');

    my ($ok, $msg) = $t->SetOwner($linus);
    ok($ok, "set owner: $msg");
    is($t->OwnerObj->id, $linus->id, 'owner linus');

    ($ok, $msg) = $t->AddWatcher(Type => 'Requestor', Principal => $ricky->PrincipalObj);
    ok($ok, "add requestor: $msg");
    is($t->RequestorAddresses, $ricky->EmailAddress, 'requestor ricky');

    ($ok, $msg) = $t->AddWatcher(Type => 'AdminCc', Principal => $blake->PrincipalObj);
    ok($ok, "add admincc: $msg");
    is($t->AdminCcAddresses, $blake->EmailAddress, 'admincc blake');

    ($ok, $msg) = $t->AddWatcher(Type => 'Cc', Principal => $moss->PrincipalObj);
    ok($ok, "add cc: $msg");
    is($t->CcAddresses, $moss->EmailAddress, 'cc moss');

    ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => $ricky->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), $ricky->EmailAddress, 'sales ricky');

    ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => $moss->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add sales: $msg");
    is($t->RoleAddresses($sales->GroupType), (join ', ', sort $ricky->EmailAddress, $moss->EmailAddress), 'sales ricky and moss');

    ($ok, $msg) = $t->DeleteWatcher(Type => $sales->GroupType, PrincipalId => $moss->PrincipalId);
    ok($ok, "remove sales: $msg");
    is($t->RoleAddresses($sales->GroupType), $ricky->EmailAddress, 'sales ricky');

    ($ok, $msg) = $t->DeleteWatcher(Type => $sales->GroupType, PrincipalId => $ricky->PrincipalId);
    ok($ok, "remove sales: $msg");
    is($t->RoleAddresses($sales->GroupType), '', 'sales empty');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $linus->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'engineer linus');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $blake->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), $blake->EmailAddress, 'engineer blake (single-member role so linus gets displaced)');
    ($ok, $msg) = $blake->SetDisabled(1);
    ok($ok, 'temporarily disable user blake');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $moss->PrincipalObj);
    ok($ok, "add engineer: $msg");
    like($msg, qr/changed from blake\@example\.com to moss\@example\.com/, 'message of AddWatcher');
    is($t->RoleAddresses($engineer->GroupType), $moss->EmailAddress, 'engineer moss (single-member role so black gets displaced)');
    ($ok, $msg) = $blake->SetDisabled(0);
    ok($ok, 're-enable user blake');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "add engineer: $msg");
    is($t->RoleAddresses($engineer->GroupType), '', 'engineer nobody (single-member role so blake gets displaced)');

    ($ok, $msg) = $t->AddWatcher(Type => $unapplied->GroupType, Principal => $linus->PrincipalObj);
    ok(!$ok, "did not add unapplied role member: $msg");
    like($msg, qr/That role is invalid for this object/);
    is($t->RoleAddresses($unapplied->GroupType), '', 'no unapplied members');

    txn_messages_like($t, [
        qr/Owner set to linus\@example\.com/,
        qr/Requestor ricky\.roma\@example\.com added/,
        qr/AdminCc blake\@example\.com added/,
        qr/Cc moss\@example\.com added/,
        qr/Sales-$$ ricky\.roma\@example\.com added/,
        qr/Sales-$$ moss\@example\.com added/,
        qr/Sales-$$ Nobody in particular added/,
        qr/Sales-$$ moss\@example\.com deleted/,
        qr/Sales-$$ ricky\.roma\@example\.com deleted/,
        qr/Engineer-$$ set to linus\@example\.com/,
        qr/Engineer-$$ set to blake\@example\.com/,
        qr/Engineer-$$ set to moss\@example\.com/,
        qr/Engineer-$$ set to Nobody in particular/,
    ]);
}

diag 'groups can be role members' if $ENV{'TEST_VERBOSE'};
{
    my $t = RT::Test->create_ticket(
        Queue   => $specs,
        Subject => 'groups',
    );

    my ($ok, $msg) = $t->AddWatcher(Type => $sales->GroupType, Principal => $team->PrincipalObj);
    ok($ok, "add team: $msg");
    is($t->RoleAddresses($sales->GroupType), (join ', ', sort $blake->EmailAddress, $ricky->EmailAddress, $moss->EmailAddress, $williamson->EmailAddress), 'sales is all the team members');

    ($ok, $msg) = $t->AddWatcher(Type => $engineer->GroupType, Principal => $team->PrincipalObj);
    ok(!$ok, "could not add team: $msg");
    like($msg, qr/cannot be a group/);
    is($t->RoleAddresses($engineer->GroupType), '', 'engineer is still nobody');

    txn_messages_like($t, [
        qr/Sales-$$ group Team added/,
    ]);
}

done_testing;
