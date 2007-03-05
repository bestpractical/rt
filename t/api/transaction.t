
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 67 lib/RT/Transaction_Overlay.pm

ok(require RT::Transaction);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
