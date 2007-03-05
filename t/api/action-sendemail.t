
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 79 lib/RT/Action/SendEmail.pm

ok (require RT::Action::SendEmail);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
