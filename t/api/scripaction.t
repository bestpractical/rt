
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 63 lib/RT/ScripAction_Overlay.pm

ok (require RT::ScripAction);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
