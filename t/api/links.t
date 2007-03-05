
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 63 lib/RT/Links_Overlay.pm

ok (require RT::Links);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
