#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use RT::Test tests => 14;
my %clicky;

BEGIN {

    %clicky = map { $_ => 1 } grep $_, RT->Config->Get('Active_MakeClicky');

# this's hack: we have to use RT::Test first to get RT->Config work, this
# results in the fact that we can't plan any more
    unless ( keys %clicky ) {
      SKIP: {
            skip "No active Make Clicky actions", 14;
        }
        exit 0;
    }
}

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

{

my $message = MIME::Entity->build(
    Type    => 'text/html',
    Subject => 'test',
    Data    => <<END,
If you have some problems with RT you could find help
on <a href="http://wiki.bestpractical.com">wiki</a> 
or find known bugs on http://rt3.fsck.com
--
Best regards. BestPractical Team.
END
);

my $ticket = new RT::Ticket($CurrentUser);
my ($id) = $ticket->Create(
    Subject => 'test',
    Queue   => $queue->Id,
    MIMEObj => $message,
);
ok( $id,                                   "We created a ticket #$id" );
ok( $ticket->Transactions->First->Content, "Has some content" );

ok $m->login, 'logged in';
ok $m->goto_ticket($id), 'opened diplay page of the ticket';

SKIP: {
    skip "httpurl action disabled", 2 unless $clicky{'httpurl'};
    my @links = $m->find_link(
        tag  => 'a',
        url  => 'http://wiki.bestpractical.com',
        text => 'Open URL',
    );
    ok( @links == 0, 'not make clicky links clicky twice' );

    @links = $m->find_link(
        tag  => 'a',
        url  => 'http://rt3.fsck.com',
        text => 'Open URL',
    );
    ok( scalar @links, 'found clicky link' );
}

}
