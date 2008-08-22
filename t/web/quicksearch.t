#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 7;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

# merged tickets still show up in search
my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
$t1->create(
    subject   => 'base ticket'.$$,
    queue     => 'general',
    owner     => 'root',
    requestor => 'customsearch@localhost',
    mime_obj   => MIME::Entity->build(
        From    => 'customsearch@localhost',
        To      => 'rt@localhost',
        Subject => 'base ticket'.$$,
        Data    => "DON'T SEARCH FOR ME",
    ),
);
ok(my $id1 = $t1->id, 'created ticket for custom search');

my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
$t2->create(
    subject   => 'merged away'.$$,
    queue     => 'general',
    owner     => 'root',
    requestor => 'customsearch@localhost',
    mime_obj   => MIME::Entity->build(
        From    => 'customsearch@localhost',
        To      => 'rt@localhost',
        Subject => 'merged away'.$$,
        Data    => "MERGEDAWAY",
    ),
);
ok(my $id2 = $t2->id, 'created ticket for custom search');

my ($ok, $msg) = $t2->merge_into($id1);
ok($ok, "merge: $msg");

ok($m->login, 'logged in');

$m->form_with_fields('q');
$m->field(q => 'fulltext:MERGEDAWAY');
TODO:  {
    local $TODO = "We don't yet handle merged ticket content searches right";
$m->content_contains('Found 1 ticket');
}
$m->content_contains('base ticket', "base ticket is found, not the merged-away ticket");
