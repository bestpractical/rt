#!/usr/bin/perl

use strict;
use warnings;

use RT::Test; use Test::More;


my %clicky = map { $_ => 1 } grep $_, RT->Config->Get('Active_MakeClicky');
if ( keys %clicky ) {
    plan 'no_plan';
} else {
    plan skip_all => 'No active Make Clicky actions';
}


my ($baseurl, $m) = RT::Test->started_ok;

use_ok('MIME::Entity');

my $CurrentUser = RT->SystemUser;

my $queue = new RT::Model::Queue($CurrentUser);
$queue->load('General') || Abort(loc("Queue could not be loaded."));

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

my $ticket = new RT::Model::Ticket( $CurrentUser );
my ($id) = $ticket->create(
    Subject => 'test',
    Queue => $queue->id,
    MIMEObj => $message,
);
ok($id, "We Created a ticket #$id");
ok($ticket->Transactions->first->Content, "Has some content");

ok $m->login, 'logged in';
ok $m->goto_ticket($id), 'opened diplay page of the ticket';

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

