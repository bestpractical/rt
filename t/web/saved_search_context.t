#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test no_plan => 1;
my ( $url, $m ) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for (['x', 50], ['y', 40], ['z', 30]) {
    $ticket->Create(
        Subject   => $_->[0],
        Queue     => 'general',
        Owner     => 'root',
        Priority  => $_->[1],
        Requestor => 'root@localhost',
    );
}

ok( $m->login, 'logged in' );

$m->get($url . '/Search/Build.html?NewQuery=1');
$m->form_name('BuildQuery');
$m->field(ValueOfPriority => 45);
$m->click('DoSearch');
#RT->Logger->error($m->uri); sleep 100;
#{ open my $fh, '>', 'm.html'; print $fh $m->content; close $fh; }; die;
$m->text_contains('Found 2 tickets');

$m->follow_link(id => 'page-edit_search');
$m->form_name('BuildQuery');
$m->field(ValueOfAttachment => 'z');
$m->click('DoSearch');

$m->text_contains('Found 1 ticket');

$m->follow_link(id => 'page-bulk');

$m->form_name('BulkUpdate');
ok(!$m->value('UpdateTicket2'), "There is no Ticket #2 in the search's bulk update");
