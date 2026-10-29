use strict;
use warnings;

# A lifecycle whose status names are not all lower-case, merged in alongside
# the shipped defaults (hash configs merge top-level keys). Used to prove the
# endpoint keeps transition from/to in the same case as the status nodes.
my $config;

BEGIN {
    $config = <<'END';
Set(%Lifecycles,
    PascalCase => {
        type     => 'ticket',
        initial  => ['Triage'],
        active   => ['In Progress'],
        inactive => ['Done'],
        defaults => { on_create => 'Triage' },
        transitions => {
            ''            => ['Triage'],
            'Triage'      => ['In Progress'],
            'In Progress' => ['Done', 'Triage'],
            'Done'        => [],
        },
        actions => {
            'Triage -> In Progress' => { label => 'Start work', update => 'Respond' },
        },
    },
);
END
}

use RT::Test::REST2 tests => undef, config => $config;
use Test::Deep;

my $mech           = RT::Test::REST2->mech;
my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue->id, 'loaded General queue';

my $ticket = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 'lifecycle endpoint test'
);
ok $ticket->id, 'created a ticket';
is $ticket->Status, 'new', 'ticket starts new';

my $url = "$rest_base_path/ticket/" . $ticket->id . "/lifecycle";

# -- Permission checks --

diag "without ShowTicket the endpoint is forbidden";
{
    my $res = $mech->get( $url, 'Authorization' => $auth );
    is $res->code, 403, 'GET /ticket/:id/lifecycle forbidden without ShowTicket';
}

diag "a nonexistent ticket is a 404, not a 403";
{
    my $res = $mech->get( "$rest_base_path/ticket/999999/lifecycle", 'Authorization' => $auth );
    is $res->code, 404, 'nonexistent ticket returns 404';
}

$user->PrincipalObj->GrantRight( Right => $_, Object => $queue )
    for qw/SeeQueue ShowTicket/;

# -- View-only user: graph is just the current status --

diag "a view-only user sees only the current status and no transitions";
{
    my $res = $mech->get( $url, 'Authorization' => $auth );
    is $res->code, 200, 'GET succeeds with ShowTicket';

    my $content = $mech->json_response;
    is $content->{id},   $ticket->id, 'id matches';
    is $content->{type}, 'ticket',    'type is ticket';
    is $content->{name}, 'default',   'lifecycle name';
    like $content->{_url}, qr{/ticket/@{[$ticket->id]}/lifecycle$}, '_url present';

    is $content->{status}{name},     'new',     'current status is new';
    is $content->{status}{category}, 'initial', 'new is an initial status';
    ok $content->{status}{description}, 'current status carries a description';
    ok $content->{status}{notes},       'current status carries agent-facing notes';

    is_deeply [ map { $_->{name} } @{ $content->{statuses} } ], ['new'],
        'view-only: only the current status is reachable';
    is_deeply $content->{transitions}, [], 'view-only: no transitions available';
}

# -- A user who can modify the ticket --

$user->PrincipalObj->GrantRight( Right => 'ModifyTicket', Object => $queue );

my $find = sub {
    my ( $list, $from, $to ) = @_;
    my ($match) = grep { $_->{from} eq $from && $_->{to} eq $to } @$list;
    return $match;
};

diag "a modifying user gets the reachable graph with metadata";
{
    my $res = $mech->get( $url, 'Authorization' => $auth );
    is $res->code, 200, 'GET succeeds';
    my $content = $mech->json_response;

    # Everything but deleted is reachable; deleted needs DeleteTicket.
    is_deeply [ sort map { $_->{name} } @{ $content->{statuses} } ],
        [qw(new open rejected resolved stalled)],
        'modifier reaches every status but deleted';

    my ($new) = grep { $_->{name} eq 'new' } @{ $content->{statuses} };
    ok $new->{current}, 'the current status is flagged current';

    # No transition anywhere in the graph leads to deleted.
    ok !( grep { $_->{to} eq 'deleted' } @{ $content->{transitions} } ), 'no kept transition leads to deleted';

    # A directly-available transition, with action label and metadata.
    my $open = $find->( $content->{transitions}, 'new', 'open' );
    ok $open,              'new -> open transition present';
    ok $open->{available}, 'new -> open is available from the current status';
    is $open->{label},       'Open It',                      'new -> open carries its action label';
    is $open->{update},      'Respond',                      'new -> open notes the expected reply';
    is $open->{description}, 'Begin working on the ticket.', 'new -> open description';
    is $open->{notes},       'Often done when someone has also taken ownership.', 'new -> open agent-facing notes';

    # A transition whose description comes from a wildcard ('* -> rejected').
    my $reject = $find->( $content->{transitions}, 'new', 'rejected' );
    ok $reject,              'new -> rejected transition present';
    ok $reject->{available}, 'new -> rejected is available now';
    is $reject->{description},
        q{Close without action - invalid, duplicate, or won't-fix.},
        'new -> rejected description from the * -> rejected wildcard';

    # A transition that exists in the reachable graph but is not a move you can
    # make right now (it starts from a status other than the current one).
    my ($not_now) = grep { !$_->{available} } @{ $content->{transitions} };
    ok $not_now, 'graph includes transitions not available from the current status';
    isnt $not_now->{from}, 'new', 'an unavailable transition starts elsewhere';
}

# -- A lifecycle with capitalized status names --

diag "transition from/to keep the same case as the status nodes";
{
    my $queue = RT::Queue->new( RT->SystemUser );
    my ( $qid, $qmsg ) = $queue->Create( Name => 'PascalQueue', Lifecycle => 'PascalCase' );
    ok $qid, "created a queue on the PascalCase lifecycle ($qmsg)";

    $user->PrincipalObj->GrantRight( Right => $_, Object => $queue )
        for qw/SeeQueue ShowTicket ModifyTicket/;

    my $ticket = RT::Test->create_ticket( Queue => $qid, Subject => 'pascal' );
    ok $ticket->id, 'created a ticket on the PascalCase lifecycle';
    is $ticket->Status, 'Triage', 'ticket starts in Triage (canonical case)';

    my $res = $mech->get( "$rest_base_path/ticket/" . $ticket->id . "/lifecycle", 'Authorization' => $auth );
    is $res->code, 200, 'GET succeeds';
    my $content = $mech->json_response;

    is $content->{status}{name}, 'Triage', 'current status keeps canonical case';

    # Status node names keep their canonical case.
    my %name = map { lc $_->{name} => $_->{name} } @{ $content->{statuses} };
    is $name{'in progress'}, 'In Progress', 'status node name keeps canonical case';

    # Every transition endpoint must match a status node's exact case, not a
    # lower-cased variant (regression: from was emitted lower-cased).
    for my $t ( @{ $content->{transitions} } ) {
        is $t->{from}, $name{ lc $t->{from} }, "transition from '$t->{from}' matches a status node's case";
        is $t->{to},   $name{ lc $t->{to} },   "transition to '$t->{to}' matches a status node's case";
    }

    my ($available) = grep { $_->{available} } @{ $content->{transitions} };
    is $available->{from}, 'Triage', 'available transition from is canonical-cased Triage, not triage';
}

# -- Assets use the same endpoint --

diag "the asset endpoint works the same way";
{
    require RT::Test::Assets;
    my $catalog = RT::Test::Assets->load_or_create_catalog( Name => 'General assets' );
    ok $catalog->id, 'loaded a catalog';

    my $asset = RT::Asset->new( RT->SystemUser );
    my ($aid) = $asset->Create( Catalog => $catalog->id, Name => 'an asset' );
    ok $aid, 'created an asset';

    $user->PrincipalObj->GrantRight( Right => $_, Object => $catalog )
        for qw/ShowCatalog ShowAsset ModifyAsset/;

    my $res = $mech->get( "$rest_base_path/asset/$aid/lifecycle", 'Authorization' => $auth );
    is $res->code, 200, 'GET /asset/:id/lifecycle succeeds';

    my $content = $mech->json_response;
    is $content->{id},           $aid,     'asset id matches';
    is $content->{type},         'asset',  'type is asset';
    is $content->{name},         'assets', 'asset lifecycle name';
    is $content->{status}{name}, 'new',    'asset starts new';
    ok scalar @{ $content->{transitions} }, 'asset has reachable transitions';

    # Inline on the asset record too.
    $res = $mech->get( "$rest_base_path/asset/$aid?fields=Lifecycle", 'Authorization' => $auth );
    is $res->code,                              200,      'asset GET with fields=Lifecycle succeeds';
    is $mech->json_response->{Lifecycle}{name}, 'assets', 'asset GET with fields=Lifecycle embeds the lifecycle block';
}

# -- Inline expansion on the record itself via ?fields=Lifecycle --

diag "GET /ticket/:id?fields=Lifecycle embeds the same block";
{
    # Without the field, no lifecycle block.
    my $res = $mech->get( "$rest_base_path/ticket/" . $ticket->id, 'Authorization' => $auth );
    is $res->code, 200, 'plain ticket GET succeeds';
    ok !exists $mech->json_response->{Lifecycle}, 'no Lifecycle block unless requested';

    # With it, the embedded block matches the standalone endpoint exactly.
    $res = $mech->get( "$rest_base_path/ticket/" . $ticket->id . "?fields=Lifecycle", 'Authorization' => $auth );
    is $res->code, 200, 'ticket GET with fields=Lifecycle succeeds';
    my $embedded = $mech->json_response->{Lifecycle};
    ok $embedded, 'Lifecycle block present';

    $res = $mech->get( $url, 'Authorization' => $auth );
    my $standalone = $mech->json_response;

    is_deeply $embedded, $standalone, 'embedded block is identical to the standalone /lifecycle response';
}

done_testing;
