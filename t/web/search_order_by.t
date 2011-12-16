#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test tests => undef;

# TODO generalize this into a series of (currently
# unwritten) Advanced Search tests


my $ticket = RT::Test->create_ticket(
    Subject => 'test ticket',
    Queue   => 'General',
);

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Create a ticket with content and an attachment
$m->get_ok( $baseurl . '/Search/Build.html' );

$m->form_name('BuildQuery');
$m->field(OrderBy => 'id||Due');
$m->field(Query => 'id > 0');
$m->click_button(name => 'DoSearch');

$m->text_contains('Found 1 ticket');

undef $m;
done_testing();
