use strict;
use warnings;
use utf8;
use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok({text => 'About me'});
$m->submit_form_ok({ with_fields => { Lang => 'ja'} },
               "Change to Japanese");
$m->text_contains("Lang changed from (no value) to 'ja'");
$m->text_contains("実名", "Page content is japanese");

# we only changed one field, and it wasn't the default, so this feedback is
# spurious and annoying
$m->content_lacks("That is already the current value");

# change back to English
$m->submit_form_ok({ with_fields => { Lang => 'en_us'} },
               "Change back to english");

# This message shows up in Japanese
# $m->text_contains("Lang changed from 'ja' to 'en_us'");
$m->text_contains("Langは「'ja'」から「'en_us'」に変更されました");
$m->text_contains("Real Name", "Page content is english");

# Check for a lack of spurious updates
$m->content_lacks("That is already the current value");

# Ensure that we can change the language back to the default.
$m->submit_form_ok({ with_fields => { Lang => 'ja'} },
                   "Back briefly to Japanese");
$m->text_contains("Lang changed from 'en_us' to 'ja'");
$m->text_contains("実名", "Page content is japanese");
$m->submit_form_ok({ with_fields => { Lang => ''} },
                   "And set to the default");
$m->text_contains("Langは「'ja'」から「(値なし)」に変更されました");
$m->text_contains("Real Name", "Page content is english");

undef $m;

done_testing;
