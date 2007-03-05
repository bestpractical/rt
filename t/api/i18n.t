
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use_ok (RT::I18N);
ok(RT::I18N->Init);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok(my $chinese = RT::I18N->get_handle('zh_tw'));
ok(UNIVERSAL::can($chinese, 'maketext'));
ok($chinese->maketext('__Content-Type') =~ /utf-8/i, "Found the utf-8 charset for traditional chinese in the string ".$chinese->maketext('__Content-Type'));
ok($chinese->encoding eq 'utf-8', "The encoding is 'utf-8' -".$chinese->encoding);

ok(my $en = RT::I18N->get_handle('en'));
ok(UNIVERSAL::can($en, 'maketext'));
ok($en->encoding eq 'utf-8', "The encoding ".$en->encoding." is 'utf-8'");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
