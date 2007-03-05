
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::GroupMember);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
