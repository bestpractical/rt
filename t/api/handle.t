
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 58 lib/RT/Handle.pm

ok(require RT::Handle);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
