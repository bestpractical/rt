use strict;
use warnings;

use RT::Test tests => 12;
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;
ok $m->login, 'logged in';

my @tickets;
for my $ticket_num (1..3) {
    my $t = RT::Ticket->new(RT->SystemUser);
    $t->Create(Subject => "test $ticket_num", Queue => 'general', Owner => 'root');
    ok(my $id = $t->id, "created ticket $ticket_num");
    push @tickets, $t;
}

my ($t1, $t2, $t3) = @tickets;

my ($status, $msg) = $t2->AddLink( Type => 'DependsOn', Base => $t1->id );
ok($status, "created a link: $msg");

($status, $msg) = $t3->AddLink( Type => 'DependsOn', Base => $t1->id );
ok($status, "created a link: $msg");

($status, $msg) = $t3->AddLink( Type => 'DependsOn', Base => $t2->id );
ok($status, "created a link: $msg");

$m->reload();

$m->content_contains('pending ticket #'.$t3->id.'', 'single ticket pending text');
$m->content_contains('pending 2 other tickets', 'multiple tickets pending text');
