use strict;
use warnings;

use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;

my $user_a = RT::Test->load_or_create_user(
    Name         => 'user_a',
    Password     => 'password',
    EmailAddress => 'user_a@example.com',
    Privileged   => 0,
);
ok( $user_a && $user_a->id, 'created unprivileged user' );
ok( !$user_a->Privileged,   'user is not privileged' );

# Grant ShowTicket to the system Requestor role so user_a can see tickets
# where they are the requestor.
my $requestor_group = RT::System->RoleGroup('Requestor');
ok( $requestor_group->id, 'loaded system Requestor role group' );
RT::Test->add_rights( { Principal => $requestor_group, Right => ['ShowTicket'] } );

# A ticket where user_a is the requestor (watcher)
my ($watcher_ticket) = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => "selftest-$$ watcher ticket",
    Requestor => 'user_a@example.com',
);
ok( $watcher_ticket->id, 'created watcher ticket' );

# A ticket where user_a is NOT a watcher but subject shares the search token
my ($other_ticket) = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => "selftest-$$ other ticket",
);
ok( $other_ticket->id, 'created non-watcher ticket' );

ok( $m->login( 'user_a', 'password' ), 'logged in as unprivileged user' );

diag 'Test Simple Search nav link is present by default';
{
    $m->get_ok( '/SelfService/', 'loaded SelfService home page' );
    ok( $m->find_link( text => 'Simple Search' ), 'Simple Search nav link present' );
}

diag 'Test SimpleSearch.html is accessible and shows form when no query given';
{
    $m->get_ok( '/SelfService/SimpleSearch.html', 'loaded SimpleSearch page' );
    $m->title_is( 'Search for tickets', 'page title correct' );

    my $dom = $m->dom;
    ok( $dom->at('#SimpleSearchForm'),  'search form container present' );
    ok( $dom->at('input[name="q"]'),    'search input present' );
    ok( $dom->at('input[type="submit"]'), 'submit button present' );
    ok( $dom->at('table.table'),        'help table present' );
    $m->content_contains( 'Simple Search Help', 'help section heading present' );
}

diag 'Test search returns watcher ticket and excludes non-watcher ticket';
{
    $m->get_ok( "/SelfService/SimpleSearch.html?q=selftest-$$", 'searched with unique token' );

    my $dom   = $m->dom;
    my $table = $dom->at('table.collection-as-table');
    ok( $table, 'results table present' );

    my @rows = $table->find('tbody tr')->each;
    is( scalar @rows, 1, 'exactly one result row returned' );

    $m->content_contains( "selftest-$$ watcher ticket", 'watcher ticket in results' );
    $m->content_lacks( "selftest-$$ other ticket",   'non-watcher ticket excluded from results' );
}

diag 'Test result links point to SelfService display URL';
{
    my $dom   = $m->dom;
    my $table = $dom->at('table.collection-as-table');

    ok( $table->at('a[href*="SelfService/Display.html"]'), 'result link points to SelfService Display' );
    ok( !$table->at('a[href*="/Ticket/Display.html"]'),    'no privileged ticket links in results' );
}

diag 'Test direct ticket ID search redirects to SelfService display page';
{
    $m->get_ok( '/SelfService/SimpleSearch.html?q=' . $watcher_ticket->id, 'searched for ticket ID' );
    like( $m->uri, qr{/SelfService/Display\.html\?id=\d+}, 'redirected to SelfService Display URL' );
}

diag 'Test SelfServiceSimpleSearch config disabled hides nav link';
{
    RT::Test->stop_server;
    RT->Config->Set( SelfServiceSimpleSearch => 0 );
    ( $url, $m ) = RT::Test->started_ok;

    ok( $m->login( 'user_a', 'password' ), 'logged in as unprivileged user' );
    $m->get_ok( '/SelfService/', 'loaded SelfService home page' );
    ok( !$m->find_link( text => 'Simple Search' ), 'Simple Search nav link absent when config disabled' );
}

done_testing;
