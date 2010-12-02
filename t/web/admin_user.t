#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 7;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

my $root = RT::User->new( $RT::SystemUser );
$root->Load('root');
ok( $root->id, 'loaded root' );


diag "test the history page" if $ENV{TEST_VERBOSE};
$m->get_ok( $url . '/Admin/Users/History.html?id=' . $root->id );
$m->content_contains('User created', 'has User created entry');

# TODO more /Admin/Users tests

