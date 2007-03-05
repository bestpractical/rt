
use Test::More qw/no_plan/;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok(require RT::ACL);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
