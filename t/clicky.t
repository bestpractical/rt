#!/usr/bin/perl

use strict;
use warnings;

use RT::Test; use Test::More;


my %clicky = map { $_ => 1 } grep $_, RT->config->get('ActiveMakeClicky');
if ( keys %clicky ) {
    plan tests => 8;
} else {
    plan skip_all => 'No active Make Clicky actions';
}


my ($baseurl, $m) = RT::Test->started_ok;

use_ok('MIME::Entity');

my $CurrentUser = RT->system_user;

my $queue = RT::Model::Queue->new( current_user => $CurrentUser );
$queue->load('General') || abort(_("Queue could not be loaded."));

my $message = MIME::Entity->build(
    subject => 'test',
    Data    => <<END,
If you have some problems with RT you could find help
on http://wiki.bestpractical.com or subscribe to
the rt-users\@lists.bestpractical.com.

--
Best regards. BestPractical Team.
END
);

my $ticket = RT::Model::Ticket->new( current_user => $CurrentUser );
my ($id) = $ticket->create(
    subject => 'test',
    queue => $queue->id,
    mime_obj => $message,
);
ok($id, "We Created a ticket #$id");
ok($ticket->transactions->first->content, "Has some content");

ok $m->login, 'logged in';
ok $m->goto_ticket($id), 'opened diplay page of the ticket';

SKIP: {
    skip "httpurl action disabled", 1 unless $clicky{'httpurl'};
    my @links = $m->find_link(
        tag => 'a',
        url => 'http://wiki.bestpractical.com',
        text => 'Open URL',
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

