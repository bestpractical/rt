
use strict;
use warnings;
use Test::More;
use RT::Test tests => undef;

my $plain = MIME::Entity->build(
    Subject => 'plain mime',
    Type    => 'text/plain',
    Data    => <<END,
If you have some problems with RT you could find help
on http://wiki.bestpractical.com or subscribe to
the rt-users\@lists.bestpractical.com.

to test anchor:
https://wiki.bestpractical.com/test#anchor
--
Best regards. BestPractical Team.
END
);

my $html = MIME::Entity->build(
    Type    => 'text/html',
    Subject => 'html mime',
    Data    => <<END,
If you have some problems with RT you could find help
on <a href="http://wiki.bestpractical.com">wiki</a> 
or find known bugs on http://rt3.fsck.com

to test anchor:
https://wiki.bestpractical.com/test#anchor
--
Best regards. BestPractical Team.
END
);


my $ticket = RT::Ticket->new( RT->SystemUser );

my ($plain_id) = $ticket->Create(
    Subject => 'test',
    Queue => 'General',
    MIMEObj => $plain,
);
ok($plain_id, "We created a ticket #$plain_id");

my ($html_id) = $ticket->Create(
    Subject => 'test',
    Queue => 'General',
    MIMEObj => $html,
);
ok($html_id, "We created a ticket #$html_id");

diag 'test no clicky';
{
    RT->Config->Set( 'Active_MakeClicky' => () );
    my ( $baseurl, $m ) = RT::Test->started_ok;
    ok $m->login, 'logged in';
    $m->goto_ticket($plain_id);

    my @links = $m->find_link(
        tag  => 'a',
        url  => 'http://wiki.bestpractical.com',
    );
    ok( @links == 0, 'no clicky link found with plain message' );

    @links = $m->find_link(
        tag  => 'a',
        url  => 'http://rt3.fsck.com',
    );
    ok( @links == 0, 'no extra clicky link found with html message' );
}

diag 'test httpurl';
{
    RT::Test->stop_server;
    RT->Config->Set( 'Active_MakeClicky' => qw/httpurl/ );
    my ( $baseurl, $m ) = RT::Test->started_ok;
    ok $m->login, 'logged in';
    $m->goto_ticket($plain_id);

    my @links = $m->find_link(
        tag  => 'a',
        url  => 'http://wiki.bestpractical.com',
        text => 'Open URL',
    );
    ok( scalar @links, 'found clicky link' );

    @links = $m->find_link(
        tag  => 'a',
        url  => 'https://wiki.bestpractical.com/test#anchor',
        text => 'Open URL',
    );
    ok( scalar @links, 'found clicky link with anchor' );

    $m->goto_ticket($html_id);
    @links = $m->find_link(
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

    @links = $m->find_link(
        tag  => 'a',
        url  => 'https://wiki.bestpractical.com/test#anchor',
        text => 'Open URL',
    );
    ok( scalar @links, 'found clicky link with anchor' );
}

diag 'test httpurl_overwrite';
{
    RT::Test->stop_server;
    RT->Config->Set( 'Active_MakeClicky' => 'httpurl_overwrite' );
    my ( $baseurl, $m ) = RT::Test->started_ok;
    ok $m->login, 'logged in';
    ok $m->goto_ticket($plain_id), 'opened diplay page of the ticket';

    my @links = $m->find_link(
        tag => 'a',
        url => 'http://wiki.bestpractical.com',
        text => 'http://wiki.bestpractical.com',
    );
    ok( scalar @links, 'found clicky link' );

    @links = $m->find_link(
        tag  => 'a',
        url  => 'https://wiki.bestpractical.com/test#anchor',
        text => 'https://wiki.bestpractical.com/test#anchor',
    );
    ok( scalar @links, 'found clicky link with anchor' );
}

done_testing;
