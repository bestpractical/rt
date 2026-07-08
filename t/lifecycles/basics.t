use strict;
use warnings;
use Storable ();

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

diag "check StatusMetadata";
{
    my $schema = $general->LifecycleObj;

    is_deeply $schema->StatusMetadata('open'),
        {   description => 'Work is actively underway.',
            notes       => 'Set to open when you begin working on the ticket.'
        },
        'open: both fields';

    is_deeply $schema->StatusMetadata('OPEN'),
        {   description => 'Work is actively underway.',
            notes       => 'Set to open when you begin working on the ticket.'
        },
        'lookup is case-insensitive';

    is_deeply $schema->StatusMetadata('stalled'),
        { description => 'Blocked, waiting on something external.' },
        'stalled: description only';

    is_deeply $schema->StatusMetadata('new'),   {}, 'status with no metadata -> empty hash';
    is_deeply $schema->StatusMetadata('bogus'), {}, 'unknown status -> empty hash';
    is_deeply $schema->StatusMetadata(''),      {}, 'empty status -> empty hash';
    is_deeply $schema->StatusMetadata(undef),   {}, 'undef status -> empty hash';
}

diag "check TransitionMetadata wildcard-merge semantics";
{
    my $schema = $general->LifecycleObj;

    # Exact entry sets both fields, so the generic '* -> *' note adds nothing.
    is_deeply $schema->TransitionMetadata( from => 'open', to => 'resolved' ),
        {   description => 'The work is complete.',
            notes       => 'Resolve when finished; add a reply first.'
        },
        'open -> resolved: exact entry wins both fields';

    # open -> rejected has no exact entry. Merge order (low to high specificity):
    #   '* -> *'        notes       => generic
    #   'open -> *'     description => leaving open, notes => from-open note
    #   '* -> rejected' description => closed without action
    # description comes from '* -> rejected' (more specific than 'open -> *');
    # notes falls back to 'open -> *' (neither more-specific key sets it).
    is_deeply $schema->TransitionMetadata( from => 'open', to => 'rejected' ),
        {   description => 'Closed without action.',
            notes       => 'A from-open note.'
        },
        'open -> rejected: * -> to beats from -> *, notes falls back to from -> *';

    # new -> resolved matches only '* -> *'.
    is_deeply $schema->TransitionMetadata( from => 'new', to => 'resolved' ),
        { notes => 'A generic transition note.' },
        'new -> resolved: only the generic * -> * note applies';

    is_deeply $schema->TransitionMetadata( from => 'OPEN', to => 'Rejected' ),
        {   description => 'Closed without action.',
            notes       => 'A from-open note.'
        },
        'transition lookup is case-insensitive';

    is_deeply $schema->TransitionMetadata( from => 'stalled', to => 'open' ),
        { notes => 'A generic transition note.' },
        'transition with no specific entry falls back to the * -> * catch-all';
}

diag "check ValidateLifecycle catches bad metadata and Cleanup removes it";
{
    my $bad = {
        type            => 'ticket',
        initial         => [qw(new)],
        active          => [qw(open)],
        inactive        => [qw(done)],
        status_metadata => {
            open  => { description => 'ok', bogus => 'drop me' },
            ghost => { description => 'no such status' },
        },
        transition_metadata => {
            'open -> done'  => { notes       => 'ok', alsobad => 1 },
            'open -> ghost' => { description => 'bad target' },
            'garbage'       => { notes       => 'not a transition' },
        },
    };

    my ( $ret, @warnings ) = RT::Lifecycle->ValidateLifecycle(
        Lifecycle => $bad,
        Name      => 'testlc',
        Cleanup   => 1
    );
    ok !$ret, 'validation reports problems';

    my $warn = join "\n", @warnings;
    like $warn, qr/Nonexistent status ghost in status metadata/,       'warns: ghost status';
    like $warn, qr/Invalid metadata field bogus for status open/,      'warns: unknown status field';
    like $warn, qr/Nonexistent status ghost in transition metadata/,   'warns: ghost transition target';
    like $warn, qr/Invalid metadata field alsobad for transition/,     'warns: unknown transition field';
    like $warn, qr/Invalid transition garbage in transition metadata/, 'warns: malformed transition key';

    is_deeply $bad->{status_metadata},
        { open => { description => 'ok' } },
        'cleanup: ghost status dropped, unknown field stripped, good field kept';
    is_deeply $bad->{transition_metadata},
        { 'open -> done' => { notes => 'ok' } },
        'cleanup: bad transitions dropped, unknown field stripped, good field kept';
}

diag "check metadata round-trips through save and FillCache normalizes keys";
{
    my $obj        = RT::Lifecycle->Load( Name => 'default', Type => 'ticket' );
    my $new_config = Storable::dclone( RT->Config->Get('Lifecycles')->{default} );

    # Mixed-case and oddly-spaced keys to prove FillCache normalizes them.
    $new_config->{status_metadata}{'New'}                   = { description => 'A brand new ticket.' };
    $new_config->{transition_metadata}{'Stalled  ->  Open'} = { description => 'Resume work.' };

    my ( $ok, $msg ) = RT::Lifecycle->UpdateLifecycle(
        CurrentUser  => RT->SystemUser,
        LifecycleObj => $obj,
        NewConfig    => $new_config,
    );
    ok $ok, "saved updated lifecycle: $msg";

    RT::Lifecycle->FillCache;

    my $cache = $RT::Lifecycle::LIFECYCLES_CACHE{default};
    ok exists $cache->{status_metadata}{new},                   'status_metadata key lowercased (New -> new)';
    ok !exists $cache->{status_metadata}{New},                  'original mixed-case status key gone';
    ok exists $cache->{transition_metadata}{'stalled -> open'}, 'transition_metadata key normalized (spacing + case)';
    ok !exists $cache->{transition_metadata}{'Stalled  ->  Open'}, 'original un-normalized transition key gone';

    my $reloaded = RT::Lifecycle->Load( Name => 'default', Type => 'ticket' );
    is_deeply $reloaded->StatusMetadata('new'),
        { description => 'A brand new ticket.' },
        'newly-added status metadata survives save/reload';
    is_deeply $reloaded->TransitionMetadata( from => 'stalled', to => 'open' ),
        { description => 'Resume work.', notes => 'A generic transition note.' },
        'newly-added transition metadata survives save/reload (merged with * -> *)';
    is_deeply $reloaded->StatusMetadata('open'),
        {   description => 'Work is actively underway.',
            notes       => 'Set to open when you begin working on the ticket.'
        },
        'existing metadata still intact after save/reload';
}

diag "check ReachableStatuses honors per-transition rights";
{
    my $schema = $general->LifecycleObj;    # the default lifecycle, no custom rights

    my $reach = sub { [ sort $schema->ReachableStatuses(@_) ] };

    # With no rights at all, the user can't move anywhere: only the current
    # status comes back.
    is_deeply $reach->( From => 'new', Rights => {} ), ['new'], 'no rights -> only the current status';

    # ModifyTicket covers every default transition except '* -> deleted', which
    # CheckRight gates behind DeleteTicket, so deleted stays unreachable.
    is_deeply $reach->( From => 'new', Rights => { ModifyTicket => 1 } ),
        [qw(new open rejected resolved stalled)],
        'ModifyTicket reaches everything but deleted';

    # Granting DeleteTicket too makes deleted reachable.
    is_deeply $reach->( From => 'new', Rights => { ModifyTicket => 1, DeleteTicket => 1 } ),
        [qw(deleted new open rejected resolved stalled)],
        'with DeleteTicket, deleted is reachable';

    # SuperUser bypasses the individual rights checks.
    is_deeply $reach->( From => 'new', Rights => { SuperUser => 1 } ),
        [qw(deleted new open rejected resolved stalled)],
        'SuperUser reaches everything';

    # An explicit Allowed override replaces the rights-based default.
    is_deeply [ sort $schema->ReachableStatuses( From => 'new', Allowed => sub {0} ) ],
        ['new'], 'Allowed override denying all -> only the current status';

    # A missing/empty starting status yields nothing.
    is_deeply [ $schema->ReachableStatuses( From => '', Rights => { ModifyTicket => 1 } ) ],
        [], 'empty From -> no statuses';
}

diag "check ReachableStatuses with a custom transition right";
{
    my $triage = RT::Lifecycle->Load( Name => 'triage', Type => 'ticket' );
    isa_ok $triage, 'RT::Lifecycle';

    my $reach = sub { [ sort $triage->ReachableStatuses(@_) ] };

    # triage gates '* -> escalated' behind the custom EscalateTicket right.
    # Without it, escalated (reachable only via that transition) is dropped.
    is_deeply $reach->( From => 'untriaged', Rights => { ModifyTicket => 1 } ),
        [qw(ordinary resolved untriaged)],
        'without EscalateTicket, escalated is unreachable';

    # With the custom right, escalated opens up.
    is_deeply $reach->( From => 'untriaged', Rights => { ModifyTicket => 1, EscalateTicket => 1 } ),
        [qw(escalated ordinary resolved untriaged)],
        'EscalateTicket makes escalated reachable';
}

diag "check FilterAllowedTransitions trims the config to what a user can reach";
{
    my $ticket = RT::Test->create_ticket( Queue => $general->id, Subject => 'filter test' );
    ok $ticket->id, 'created a ticket to filter';

    my $statuses = sub {
        my $cfg = shift;
        return [ sort map { @{ $cfg->{$_} || [] } } qw/initial active inactive/ ];
    };
    my $config_for = sub {
        my $user    = shift;
        my $as_user = RT::Ticket->new( RT::CurrentUser->new($user) );
        $as_user->Load( $ticket->id );
        return $general->LifecycleObj->FilterAllowedTransitions( Object => $as_user );
    };

    # A user who can see the ticket but not modify it can't move anywhere.
    my $viewer = RT::Test->load_or_create_user( Name => 'lc-viewer', Privileged => 1 );
    $viewer->PrincipalObj->GrantRight( Right => $_, Object => $general )
        for qw/SeeQueue ShowTicket/;
    my $vcfg = $config_for->($viewer);
    is_deeply $statuses->($vcfg), ['new'], 'view-only user: only the current status';
    is_deeply $vcfg->{transitions}, {}, 'view-only user: no transitions kept';

    # ModifyTicket reaches everything but deleted, which needs DeleteTicket.
    my $modifier = RT::Test->load_or_create_user( Name => 'lc-modifier', Privileged => 1 );
    $modifier->PrincipalObj->GrantRight( Right => $_, Object => $general )
        for qw/SeeQueue ShowTicket ModifyTicket/;
    my $mcfg = $config_for->($modifier);
    is_deeply $statuses->($mcfg), [qw(new open rejected resolved stalled)], 'modifier: every status but deleted';
    ok !(
        grep { $_ eq 'deleted' }
        map  { @{ $mcfg->{transitions}{$_} } } keys %{ $mcfg->{transitions} }
        ),
        'modifier: no kept transition leads to deleted';

    # The shared lifecycle config must not be mutated by filtering.
    is_deeply(
        RT->Config->Get('Lifecycles')->{default}{inactive},
        [qw(resolved rejected deleted)],
        'original config left intact'
    );
}

diag "check FilterAllowedTransitions works for assets and asset rights";
{
    # Use the default 'assets' lifecycle; it gates '* -> *' on ModifyAsset.
    my $catalog = RT::Catalog->new( RT->SystemUser );
    my ( $cid, $cmsg ) = $catalog->Create( Name => 'Filter Test Hardware', Lifecycle => 'assets' );
    ok $cid, "created a catalog on the assets lifecycle ($cmsg)";

    my $asset = RT::Asset->new( RT->SystemUser );
    my ( $aid, $amsg ) = $asset->Create( Catalog => $cid, Name => 'a box' );
    ok $aid, "created an asset to filter ($amsg)";
    is $asset->Status, 'new', 'asset starts in the initial status';

    my $statuses = sub {
        my $cfg = shift;
        return [ sort map { @{ $cfg->{$_} || [] } } qw/initial active inactive/ ];
    };
    my $config_for = sub {
        my $user    = shift;
        my $as_user = RT::Asset->new( RT::CurrentUser->new($user) );
        $as_user->Load( $asset->id );
        return $as_user->LifecycleObj->FilterAllowedTransitions( Object => $as_user );
    };

    # A user who can see the asset but not modify it can't move anywhere.
    my $viewer = RT::Test->load_or_create_user( Name => 'asset-lc-viewer', Privileged => 1 );
    $viewer->PrincipalObj->GrantRight( Right => $_, Object => $catalog )
        for qw/ShowCatalog ShowAsset/;
    my $vcfg = $config_for->($viewer);
    is_deeply $statuses->($vcfg), ['new'], 'view-only user: only the current status';
    is_deeply $vcfg->{transitions}, {}, 'view-only user: no transitions kept';

    # ModifyAsset gates every transition, so a modifier reaches every status.
    my $modifier = RT::Test->load_or_create_user( Name => 'asset-lc-modifier', Privileged => 1 );
    $modifier->PrincipalObj->GrantRight( Right => $_, Object => $catalog )
        for qw/ShowCatalog ShowAsset ModifyAsset/;
    my $mcfg = $config_for->($modifier);
    is_deeply $statuses->($mcfg),
        [qw(allocated deleted in-use new recycled stolen)],
        'modifier: every status reachable via ModifyAsset';
    ok scalar keys %{ $mcfg->{transitions} }, 'modifier: transitions kept';

    # The shared lifecycle config must not be mutated by filtering.
    is_deeply( RT->Config->Get('Lifecycles')->{assets}{active}, [qw(allocated in-use)], 'original config left intact' );
}

diag "check LoadLifecycleLayout round-trips through UpdateLifecycleLayout";
{
    my $obj = RT::Lifecycle->Load( Name => 'default', Type => 'ticket' );

    is_deeply( RT::Lifecycle->LoadLifecycleLayout( LifecycleObj => $obj ),
        {}, 'no layout saved yet, returns an empty hashref' );

    my $layout = { new => [ 10, 20 ], open => [ 30, 40 ] };
    my ( $ok, $msg ) = RT::Lifecycle->UpdateLifecycleLayout(
        CurrentUser  => RT->SystemUser,
        LifecycleObj => $obj,
        NewLayout    => $layout,
    );
    ok $ok, 'saved a layout' or diag $msg;
    is_deeply( RT::Lifecycle->LoadLifecycleLayout( LifecycleObj => $obj ),
        $layout, 'saved layout round-trips through load' );

    # Saving again over an existing setting replaces the stored layout.
    my $layout2 = { new => [ 1, 2 ], open => [ 3, 4 ], resolved => [ 5, 6 ] };
    ( $ok, $msg ) = RT::Lifecycle->UpdateLifecycleLayout(
        CurrentUser  => RT->SystemUser,
        LifecycleObj => $obj,
        NewLayout    => $layout2,
    );
    ok $ok, 'updated the layout' or diag $msg;
    is_deeply( RT::Lifecycle->LoadLifecycleLayout( LifecycleObj => $obj ),
        $layout2, 'updated layout round-trips through load' );

    # Saving with no layout disables the setting, so load falls back to empty.
    ( $ok, $msg ) = RT::Lifecycle->UpdateLifecycleLayout(
        CurrentUser  => RT->SystemUser,
        LifecycleObj => $obj,
    );
    ok $ok, 'cleared the layout' or diag $msg;
    is_deeply( RT::Lifecycle->LoadLifecycleLayout( LifecycleObj => $obj ),
        {}, 'cleared layout falls back to an empty hashref' );
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

    $m->get_ok( '/Ticket/ModifyAll.html?id='. $tid );
    my $form = $m->form_name('TicketModifyAll');
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

    $m->get_ok( '/Ticket/ModifyAll.html?id='. $tid );
    my $form = $m->form_name('TicketModifyAll');
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

diag "Test lifecycle warnings on admin pages";
{
    no warnings 'redefine';
    local *RT::Queue::ValidateLifecycle = sub {1};
    my ( $ret, $msg ) = $general->SetLifecycle('foobar');
    ok( $ret, $msg );
    RT->System->LifecycleCacheNeedsUpdate(1);
    $m->get_ok('/Admin/Lifecycles/');
    $m->warning_like(qr/Lifecycle foobar is missing/);
    $m->text_contains('Lifecycle foobar is missing');
}

done_testing;
