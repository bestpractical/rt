#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 19;
my ( $url, $m ) = RT::Test->started_ok;
use RT::Attribute;
my $search = RT::Attribute->new($RT::SystemUser);
my $ticket = RT::Ticket->new($RT::SystemUser);
my ( $ret, $msg ) = $ticket->Create(
    Subject   => 'base ticket' . $$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'root@localhost',
    MIMEObj   => MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'base ticket' . $$,
        Data    => "",
    ),
);
ok( $ret, "ticket created: $msg" );

ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Search/Chart.html?Query=" . 'id=1' );
my ($owner) = $m->content =~ /value="(RT::User-\d+)"/;

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchDescription => 'first chart',
        SavedSearchOwner       => $owner,
    },
    button => 'SavedSearchSave',
);

$m->content_like( qr/Chart first chart saved/, 'saved first chart' );

my ( $search_uri, $id ) = $m->content =~ /value="(RT::User-\d+-SavedSearch-(\d+))"/;
$m->submit_form(
    form_name => 'SaveSearch',
    fields    => { SavedSearchLoad => $search_uri },
);

$m->content_like( qr/name="SavedSearchDelete"\s+value="Delete"/,
    'found Delete button' );
$m->content_like(
    qr/name="SavedSearchDescription"\s+value="first chart"/,
    'found Description input with the value filled'
);
$m->content_like( qr/name="SavedSearchSave"\s+value="Update"/,
    'found Update button' );
$m->content_unlike( qr/name="SavedSearchSave"\s+value="Save"/,
    'no Save button' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        Query          => 'id=2',
        PrimaryGroupBy => 'Status',
        ChartStyle     => 'pie',
    },
    button => 'SavedSearchSave',
);

$m->content_like( qr/Chart first chart updated/, 'found updated message' );
$m->content_like( qr/id=2/,                      'Query is updated' );
$m->content_like( qr/value="Status"\s+selected="selected"/,
    'PrimaryGroupBy is updated' );
$m->content_like( qr/value="pie"\s+selected="selected"/,
    'ChartType is updated' );
ok( $search->Load($id) );
is( $search->SubValue('Query'), 'id=2', 'Query is indeed updated' );
is( $search->SubValue('PrimaryGroupBy'),
    'Status', 'PrimaryGroupBy is indeed updated' );
is( $search->SubValue('ChartStyle'), 'pie', 'ChartStyle is indeed updated' );

# finally, let's test delete
$m->submit_form(
    form_name => 'SaveSearch',
    button    => 'SavedSearchDelete',
);
$m->content_like( qr/Chart first chart deleted/, 'found deleted message' );
$m->content_unlike( qr/value="RT::User-\d+-SavedSearch-\d+"/,
    'no saved search' );
