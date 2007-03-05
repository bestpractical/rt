#!/usr/bin/perl

use strict;
use warnings;

use Test::More;


my %clicky = map { $_ => 1 } grep $_, RT->Config->Get('Active_MakeClicky');
if ( keys %clicky ) {
    plan 'no_plan';
}
else {
    plan skip_all => 'No active Make Clicky actions';
}

use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

use_ok('MIME::Entity');

my $CurrentUser = $RT::SystemUser;

my $queue = new RT::Queue($CurrentUser);
$queue->Load('General') || Abort(loc("Queue could not be loaded."));

my $message = MIME::Entity->build(
    Subject => 'test',
    Data    => <<END,
If you have some problems with RT you could find help
on http://wiki.bestpractical.com or subscribe to
the rt-users\@lists.bestpractical.com.

--
Best regards. BestPractical Team.
END
);

my $ticket = new RT::Ticket( $CurrentUser );
my ($id) = $ticket->Create(
    Subject => 'test',
    Queue => $queue->Id,
    MIMEObj => $message,
);
ok($id, "We created a ticket #$id");
ok($ticket->Transactions->First->Content, "Has some content");

use constant BaseURL => "http://localhost:".RT->Config->Get('WebPort').RT->Config->Get('WebPath')."/";

$m->get_ok( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');

$m->get_ok( BaseURL."Ticket/Display.html?id=$id" );

SKIP: {
    skip "httpurl action disabled", 1 unless $clicky{'httpurl'};
    my @links = $m->find_link(
        tag => 'a',
        url => 'http://wiki.bestpractical.com',
        text => '[Open URL]',
    );
    ok( scalar @links, 'found clicky link' );
}

SKIP: {
    skip "httpurl_overwrite action disabled", 1 unless $clicky{'httpurl_overwrite'};
    my @links = $m->find_link(
        tag => 'a',
        url => 'http://wiki.bestpractical.com',
        text => 'http://wiki.bestpractical.com',
    );
    ok( scalar @links, 'found clicky link' );
}

