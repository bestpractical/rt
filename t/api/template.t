
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 62 lib/RT/Template_Overlay.pm

ok(require RT::Template);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 124 lib/RT/Template_Overlay.pm

my $t = RT::Template->new($RT::SystemUser);
$t->Create(Name => "Foo", Queue => 1);
my $t2 = RT::Template->new($RT::Nobody);
$t2->Load($t->Id);
ok($t2->QueueObj->id, "Got the template's queue objet");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
