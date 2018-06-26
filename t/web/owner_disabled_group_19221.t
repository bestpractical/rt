use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'Test' );
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name        => 'ausername',
    Privileged  => 1,
);
ok $user && $user->id, 'loaded or created user';

my $group = RT::Group->new(RT->SystemUser);
my ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Disabled Group');
ok($ok, $msg);

($ok, $msg) = $group->AddMember( $user->PrincipalId );
ok($ok, $msg);

ok( RT::Test->set_rights({
    Principal   => $group,
    Object      => $queue,
    Right       => [qw(OwnTicket)]
}), 'set rights');

RT->Config->Set( AutocompleteOwners => 0 );
my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "user from group shows up in create form";
{
    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((scalar grep { $_ == $user->Id } $input->possible_values), 'user from group is in dropdown');
}

diag "user from disabled group DOESN'T shows up in create form";
{
    ($ok, $msg) = $group->SetDisabled(1);
    ok($ok, $msg);

    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user->Id } $input->possible_values), 'user from disabled group is NOT in dropdown');
    ($ok, $msg) = $group->SetDisabled(0);
    ok($ok, $msg);
}



diag "Put us in a nested group";
my $super = RT::Group->new(RT->SystemUser);
($ok, $msg) = $super->CreateUserDefinedGroup(Name => 'Supergroup');
ok($ok, $msg);

($ok, $msg) = $super->AddMember( $group->PrincipalId );
ok($ok, $msg);

ok( RT::Test->set_rights({
    Principal   => $super,
    Object      => $queue,
    Right       => [qw(OwnTicket)]
}), 'set rights');


diag "Disable the middle group";
{
    ($ok, $msg) = $group->SetDisabled(1);
    ok($ok, "Disabled group: $msg");

    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user->Id } $input->possible_values), 'user from disabled group is NOT in dropdown');
    ($ok, $msg) = $group->SetDisabled(0);
    ok($ok, "Re-enabled group: $msg");
}

diag "Disable the top group";
{
    ($ok, $msg) = $super->SetDisabled(1);
    ok($ok, "Disabled supergroup: $msg");

    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user->Id } $input->possible_values), 'user from disabled group is NOT in dropdown');
    ($ok, $msg) = $super->SetDisabled(0);
    ok($ok, "Re-enabled supergroup: $msg");
}


diag "Check WithMember and WithoutMember recursively";
{
    my $with = RT::Groups->new( RT->SystemUser );
    $with->WithMember( PrincipalId => $user->PrincipalObj->Id, Recursively => 1 );
    $with->LimitToUserDefinedGroups;
    is_deeply(
        [map {$_->Name} @{$with->ItemsArrayRef}],
        ['Disabled Group','Supergroup'],
        "Get expected recursive memberships",
    );

    my $without = RT::Groups->new( RT->SystemUser );
    $without->WithoutMember( PrincipalId => $user->PrincipalObj->Id, Recursively => 1 );
    $without->LimitToUserDefinedGroups;
    is_deeply(
        [map {$_->Name} @{$without->ItemsArrayRef}],
        [],
        "And not a member of no groups",
    );

    ($ok, $msg) = $super->SetDisabled(1);
    ok($ok, "Disabled supergroup: $msg");
    $with->RedoSearch;
    $without->RedoSearch;
    is_deeply(
        [map {$_->Name} @{$with->ItemsArrayRef}],
        ['Disabled Group'],
        "Recursive check only contains subgroup",
    );
    is_deeply(
        [map {$_->Name} @{$without->ItemsArrayRef}],
        [],
        "Doesn't find the currently disabled group",
    );
    ($ok, $msg) = $super->SetDisabled(0);
    ok($ok, "Re-enabled supergroup: $msg");

    ($ok, $msg) = $group->SetDisabled(1);
    ok($ok, "Disabled intermediate group: $msg");
    $with->RedoSearch;
    $without->RedoSearch;
    is_deeply(
        [map {$_->Name} @{$with->ItemsArrayRef}],
        [],
        "Recursive check finds no groups",
    );
    is_deeply(
        [map {$_->Name} @{$without->ItemsArrayRef}],
        ['Supergroup'],
        "Now not a member of the supergroup",
    );
    ($ok, $msg) = $group->SetDisabled(0);
    ok($ok, "Re-enabled intermediate group: $msg");
}

diag "Check MemberOfGroup";
{
    ($ok, $msg) = $group->SetDisabled(1);
    ok($ok, "Disabled intermediate group: $msg");
    my $users = RT::Users->new(RT->SystemUser);
    $users->MemberOfGroup($super->PrincipalObj->id);
    is($users->Count, 0, "Supergroup claims no members");
    ($ok, $msg) = $group->SetDisabled(0);
    ok($ok, "Re-enabled intermediate group: $msg");
}


done_testing;
