#!/usr/bin/perl

use strict;
use warnings;
use Encode;

use RT::Test tests => 11;

diag "set groups limit to 1" if $ENV{TEST_VERBOSE};
RT->Config->Set( ShowMoreAboutPrivilegedUsers    => 1 );
RT->Config->Set( MoreAboutRequestorGroupsLimit => 1 );

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id) = $ticket->Create(
    Subject   => 'groups limit',
    Queue     => 'General',
    Requestor => 'root@localhost',
);
ok( $id, 'created ticket' );

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in as root' );
$m->get_ok( $url . '/Ticket/Display.html?id=' . $id );
$m->content_contains( 'Everyone', 'got the first group' );
$m->content_lacks( 'Privileged', 'not the second group' );

RT::Test->stop_server;

diag "set groups limit to 2" if $ENV{TEST_VERBOSE};

RT->Config->Set( MoreAboutRequestorGroupsLimit => 2 );
( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in as root' );
$m->get_ok( $url . '/Ticket/Display.html?id=' . $id );
$m->content_contains( 'Everyone', 'got the first group' );
$m->content_contains( 'Privileged', 'got the second group' );

