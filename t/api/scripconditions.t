
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 61 lib/RT/ScripConditions_Overlay.pm

ok (require RT::ScripConditions);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
