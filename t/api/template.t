
use strict;
use warnings;
use RT;
use RT::Test tests => 2;


{

ok(require RT::Template);


}

{

my $t = RT::Template->new($RT::SystemUser);
$t->Create(Name => "Foo", Queue => 1);
my $t2 = RT::Template->new($RT::Nobody);
$t2->Load($t->Id);
ok($t2->QueueObj->id, "Got the template's queue objet");


}

1;
