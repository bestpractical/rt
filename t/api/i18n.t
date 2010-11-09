
use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 9;


{

use_ok ('RT::I18N');
ok(RT::I18N->Init);


}

{

ok(my $chinese = RT::I18N->get_handle('zh_tw'));
ok(UNIVERSAL::can($chinese, 'maketext'));
like($chinese->maketext('__Content-Type') , qr/utf-8/i, "Found the utf-8 charset for traditional chinese in the string ".$chinese->maketext('__Content-Type'));
is($chinese->encoding , 'utf-8', "The encoding is 'utf-8' -".$chinese->encoding);

ok(my $en = RT::I18N->get_handle('en'));
ok(UNIVERSAL::can($en, 'maketext'));
is($en->encoding , 'utf-8', "The encoding ".$en->encoding." is 'utf-8'");


}

