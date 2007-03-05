
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 62 lib/RT/GroupMembers_Overlay.pm

ok (require RT::GroupMembers);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
