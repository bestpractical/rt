
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 62 lib/RT/Queues_Overlay.pm

ok (require RT::Queues);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
