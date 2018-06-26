use strict;
use warnings;
use RT::Test tests => 9;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok({text => 'About me'});
$m->form_with_fields('Lang');
$m->field(Lang => 'zh_TW');
$m->submit;

$m->text_contains(Encode::decode("UTF-8","電子郵件信箱"), "successfully updated to zh_TW");
$m->text_contains(Encode::decode("UTF-8","使用語言 的值從 (無) 改為 'zh_TW'"), "when updating to language zh_TW, results are in zh_TW");

$m->form_with_fields('Lang');
$m->field(Lang => 'en_us');
$m->submit;

$m->text_contains("Email", "successfully updated to en_us");
$m->text_contains("Lang changed from 'zh_TW' to 'en_us'", "when updating to language en_us, results are in en_us");

