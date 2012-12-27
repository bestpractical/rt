use strict;
use warnings;

use RT::Test tests => 9;
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

# merged tickets still show up in search
my $t1 = RT::Ticket->new(RT->SystemUser);
$t1->Create(
    Subject   => 'base ticket'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    MIMEObj   => MIME::Entity->build(
        From    => 'customsearch@localhost',
        To      => 'rt@localhost',
        Subject => 'base ticket'.$$,
        Data    => "DON'T SEARCH FOR ME",
    ),
);
ok(my $id1 = $t1->id, 'created ticket for custom search');

my $t2 = RT::Ticket->new(RT->SystemUser);
$t2->Create(
    Subject   => 'merged away'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    MIMEObj   => MIME::Entity->build(
        From    => 'customsearch@localhost',
        To      => 'rt@localhost',
        Subject => 'merged away'.$$,
        Data    => "MERGEDAWAY",
    ),
);
ok(my $id2 = $t2->id, 'created ticket for custom search');

my ($ok, $msg) = $t2->MergeInto($id1);
ok($ok, "merge: $msg");

ok($m->login, 'logged in');

$m->form_with_fields('q');
$m->field(q => 'fulltext:MERGEDAWAY');
TODO:  {
    local $TODO = "We don't yet handle merged ticket content searches right";
$m->content_contains('Found 1 ticket');
}
$m->content_contains('base ticket', "base ticket is found, not the merged-away ticket");
