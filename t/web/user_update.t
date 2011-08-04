#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use RT::Test tests => 9;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok({text => 'About me'});
$m->form_with_fields('Lang');
$m->field(Lang => 'ja');
$m->submit;

$m->text_contains("Langは「(値なし)」から「'ja'」に変更されました");

# we only changed one field, and it wasn't the default, so this feedback is
# spurious and annoying
$m->content_lacks("That is already the current value");

# change back to English
$m->form_with_fields('Lang');
$m->field(Lang => 'en_us');
$m->submit;

$m->text_contains("Lang changed from 'ja' to 'en_us'");

# another spurious update
$m->content_lacks("That is already the current value");

