
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 2;
use RT;




ok(require RT::Model::Template);

my $t = RT::Model::Template->new(current_user => RT->system_user);
$t->create(name => "Foo", Queue => 1);
my $t2 = RT::Model::Template->new(current_user => RT->nobody);
$t2->load($t->id);
ok($t2->QueueObj->id, "Got the template's queue objet");



1;
