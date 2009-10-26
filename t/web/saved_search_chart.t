#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 9;
my ( $url, $m ) = RT::Test->started_ok;

# merged tickets still show up in search
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

$m->get( $url . "/Search/Chart.html?Query=" . 'id=1' );
is( $m->{'status'}, 200, "Loaded /Search/Chart.html" );
my ($owner) = $m->content =~ /value="(RT::User-\d+)"/;

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchDescription => 'first chart',
        SavedSearchOwner       => $owner,
    },
    button => 'SavedSearchSave',
);

$m->content_like(qr/Chart first chart saved/);

my ($search) = $m->content =~ /value="(RT::User-\d+-SavedSearch-\d+)"/;
$m->submit_form(
    form_name => 'SaveSearch',
    fields      => { SavedSearchLoad => $search },
);

$m->content_like(qr/name="SavedSearchDelete"\s+value="Delete"/);
TODO: {
    local $TODO = 'add Saved Chart Search fully update support';
    $m->content_like(qr/name="SavedSearchDescription"\s+value="first chart"/);
    $m->content_like(qr/name="SavedSearchSave"\s+value="Update"/);
    $m->content_unlike(qr/name="SavedSearchSave"\s+value="Save"/);
}

