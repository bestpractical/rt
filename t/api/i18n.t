
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 12;
use RT;


ok( require RT::CurrentUser );

ok( my $cu = RT::CurrentUser->new('root') );
is( _('TEST_STRING'), "Concrete Mixer", "Localized TEST_STRING into English" );
Jifty::I18N->get_handle('FR-fr');
is( _('Before'), "Avant", "Localized TEST_STRING into French" );



use_ok ('Jifty::I18N');
ok(my $chinese = Jifty::I18N->get_language_handle('zh_tw'));
ok(UNIVERSAL::can($chinese, 'maketext'));
like($chinese->maketext('__Content-Type') , qr/utf-8/i, "Found the utf-8 charset for traditional chinese in the string ".$chinese->maketext('__Content-Type'));
is($chinese->encoding , 'utf-8', "The encoding is 'utf-8' -".$chinese->encoding);
ok(my $en = Jifty::I18N->get_language_handle('en'));
ok(UNIVERSAL::can($en, 'maketext'));
is($en->encoding , 'utf-8', "The encoding ".$en->encoding." is 'utf-8'");




1;
