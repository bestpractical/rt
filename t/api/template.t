
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 2;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok(require RT::Model::Template);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $t = RT::Model::Template->new(current_user => RT->system_user);
$t->create(name => "Foo", Queue => 1);
my $t2 = RT::Model::Template->new(RT->nobody);
$t2->load($t->id);
ok($t2->QueueObj->id, "Got the template's queue objet");


}

1;
