use strict;
use warnings;

BEGIN {require  './t/lifecycles/utils.pl'};

my $general = RT::Test->load_or_create_queue(
    Name => 'General',
);
ok $general && $general->id, 'loaded or created a queue';

my $tstatus = sub {
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $_[0] );
    return $ticket->Status;
};

diag "check basic API";
{
    my $schema = $general->LifecycleObj;
    isa_ok($schema, 'RT::Lifecycle');
    is $schema->Name, 'default', "it's a default schema";
    is_deeply [$schema->Valid],
        [qw(new open stalled resolved rejected deleted)],
        'this is the default set from our config file';

    foreach my $s ( qw(new open stalled resolved rejected deleted) ) {
        ok $schema->IsValid($s), "valid";
    }
    ok !$schema->IsValid(), 'invalid';
    ok !$schema->IsValid(''), 'invalid';
    ok !$schema->IsValid(undef), 'invalid';
    ok !$schema->IsValid('foo'), 'invalid';

    is_deeply [$schema->Initial], ['new'], 'initial set';
    ok $schema->IsInitial('new'), "initial";
    ok !$schema->IsInitial('open'), "not initial";
    ok !$schema->IsInitial, "not initial";
    ok !$schema->IsInitial(''), "not initial";
    ok !$schema->IsInitial(undef), "not initial";
    ok !$schema->IsInitial('foo'), "not initial";

    is_deeply [$schema->Active], [qw(open stalled)], 'active set';
    ok( $schema->IsActive($_), "active" )
        foreach qw(open stalled);
    ok !$schema->IsActive('new'), "not active";
    ok !$schema->IsActive, "not active";
    ok !$schema->IsActive(''), "not active";
    ok !$schema->IsActive(undef), "not active";
    ok !$schema->IsActive('foo'), "not active";

    is_deeply [$schema->Inactive], [qw(resolved rejected deleted)], 'inactive set';
    ok( $schema->IsInactive($_), "inactive" )
        foreach qw(resolved rejected deleted);
    ok !$schema->IsInactive('new'), "not inactive";
    ok !$schema->IsInactive, "not inactive";
    ok !$schema->IsInactive(''), "not inactive";
    ok !$schema->IsInactive(undef), "not inactive";
    ok !$schema->IsInactive('foo'), "not inactive";

    is_deeply [$schema->Transitions('')], [qw(new open resolved)], 'on create transitions';
    ok $schema->IsTransition('' => $_), 'good transition'
        foreach qw(new open resolved);
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "check status input on create";
{
    $m->goto_create_ticket( $general );

    my $form = $m->form_name('TicketCreate');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    my $valid = 1;
    foreach ( @form_values ) {
        next if $general->LifecycleObj->IsValid($_);
        $valid = 0;
        diag("$_ doesn't appear to be a valid status, but it was in the form");
    }


    ok $valid, 'all statuses in the form are valid';
}

diag "create a ticket";
my $tid;
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ($tid) = $ticket->Create( Queue => $general->id, Subject => 'test' );
    ok $tid, "created a ticket #$tid";
    is $ticket->Status, 'new', 'correct status';
}

diag "new ->(open it)-> open";
{
    ok $m->goto_ticket( $tid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It', 'Resolve', 'Reject', 'Delete'],
        has_no => ['Stall', 'Re-open', 'Undelete'],
    );

    $m->follow_link_ok({text => 'Open It'});
    $m->form_name('TicketUpdate');
    $m->click('SubmitTicket');

    is $tstatus->($tid), 'open', 'changed status';
}

diag "open ->(stall)-> stalled";
{
    is $tstatus->($tid), 'open', 'ticket is open';

    ok $m->goto_ticket( $tid ), 'opened a ticket';

    $m->check_links(
        has => ['Stall', 'Resolve', 'Reject'],
        has_no => ['Open It', 'Delete', 'Re-open', 'Undelete'],
    );

    $m->follow_link_ok({text => 'Stall'});
    $m->form_name('TicketUpdate');
    $m->click('SubmitTicket');

    is $tstatus->($tid), 'stalled', 'changed status';
}

diag "stall ->(open it)-> open";
{
    is $tstatus->($tid), 'stalled', 'ticket is stalled';

    ok $m->goto_ticket( $tid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It'],
        has_no => ['Delete', 'Re-open', 'Undelete', 'Stall', 'Resolve', 'Reject'],
    );

    $m->follow_link_ok({text => 'Open It'});

    is $tstatus->($tid), 'open', 'changed status';
}

diag "open -> deleted, only via modify";
{
    is $tstatus->($tid), 'open', 'ticket is open';

    $m->get_ok( '/Ticket/Modify.html?id='. $tid );
    my $form = $m->form_name('TicketModify');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    ok grep($_ eq 'deleted', @form_values), "has deleted";

    $m->select( Status => 'deleted' );
    $m->submit;

    is $tstatus->($tid), 'deleted', 'deleted ticket';
}

diag "deleted -> X via modify, only open is available";
{
    is $tstatus->($tid), 'deleted', 'ticket is deleted';

    $m->get_ok( '/Ticket/Modify.html?id='. $tid );
    my $form = $m->form_name('TicketModify');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    is join('-', @form_values), '-deleted-open', 'only default, current and open available';
}

diag "check illegal values and transitions";
{
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'illegal',
        );
        ok !$id, 'have not created a ticket';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';

        (my $status, $msg) = $ticket->SetStatus( 'illeagal' );
        ok !$status, "couldn't set illeagal status";
        is $ticket->Status, 'new', 'status is steal the same';

        ($status, $msg) = $ticket->SetStatus( 'stalled' );
        ok !$status, "couldn't set status, transition is illeagal";
        is $ticket->Status, 'new', 'status is steal the same';
    }
}

diag "'!inactive -> inactive' actions are shown even if ticket has unresolved dependencies";
{
    my $child_ticket = RT::Test->create_ticket(
        Queue => $general->id,
        Subject => 'child',
    );
    my $cid = $child_ticket->id;
    my $parent_ticket = RT::Test->create_ticket(
        Queue => $general->id,
        Subject => 'parent',
        DependsOn => $child_ticket->id,
    );
    my $pid = $parent_ticket->id;

    ok $m->goto_ticket( $pid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It', 'Resolve', 'Reject', 'Delete' ],
        has_no => ['Stall', 'Re-open', 'Undelete', ],
    );
    ok $m->goto_ticket( $cid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It', 'Resolve', 'Reject', 'Delete'],
        has_no => ['Stall', 'Re-open', 'Undelete'],
    );
}

diag "Role rights are checked for lifecycles at ticket level";
{

    my $user_a = RT::Test->load_or_create_user(
        Name => 'user_a', Password => 'password',
    );
    ok $user_a && $user_a->id, 'loaded or created user';

    RT::Test->set_rights(
        { Principal => 'AdminCc',  Right => [qw(SeeQueue)] },
        { Principal => 'Everyone', Right => [qw(WatchAsAdminCc)] },
    );

    my $ticket = RT::Test->create_ticket(Queue => 'General');
    ok $ticket->id, 'Created new ticket';
    my $id = $ticket->id;

    is $ticket->QueueObj->Lifecycle, 'default', 'Successfully loaded lifecycle';
    $ticket->AddWatcher(Type => 'AdminCc', PrincipalId => $user_a->PrincipalId);

    $ticket = RT::Ticket->new($user_a);
    my ($ret, $msg) = $ticket->Load($id);
    ok $ticket->id, 'Loaded ticket in user context';

    is $ticket->QueueObj->Lifecycle, 'default', "Rights check at ticket level passes";
}

diag "Role rights are checked for lifecycles at asset level";
{
    my $user_a = RT::Test->load_or_create_user(
        Name => 'user_a', Password => 'password',
    );
    ok $user_a && $user_a->id, 'loaded or created user';

    RT::Test->set_rights(
        { Principal => 'Owner',  Right => [qw(ShowCatalog AdminCatalog)] },
        { Principal => 'Everyone',  Right => [qw(ShowAsset ModifyAsset)] },
    );

    my $asset = RT::Asset->new(RT->SystemUser);
    my ($ret, $msg) = $asset->Create(Catalog => 'General assets');
    ok $asset->id, 'Created new asset';
    my $id = $asset->id;

    is $asset->CatalogObj->Lifecycle, 'assets', "System user can load asset without context object";

    $asset = RT::Asset->new($user_a);
    $asset->Load($id);
    ok $asset->id, 'Loaded asset in user_a context';

    is $asset->CatalogObj->Lifecycle, undef, "user_a can\'t see lifecycle without ShowCatalog and AdminCatalog";

    ($ret, $msg) = $asset->AddRoleMember(Type => 'Owner', User => $user_a);
    ok $ret, $msg;

    is $asset->CatalogObj->Lifecycle, 'assets', 'Successfully loaded lifecycle with rights check at role level';

    my $lifecycle = $asset->CatalogObj->LifecycleObj;
    is $lifecycle->Name, 'assets', 'Test LifecycleObj method';
}

done_testing;
