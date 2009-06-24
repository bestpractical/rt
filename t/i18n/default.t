#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test tests => 8;

my ($baseurl, $m) = RT::Test->started_ok;
$m->get_ok('/');
$m->title_is('Login');

$m->get_ok('/', { 'Accept-Language' => 'x-klingon' });
$m->title_is('Login', 'unavailable language fallback to en');

$m->add_header('Accept-Language' => 'zh-tw,zh;q=0.8,en-gb;q=0.5,en;q=0.3');
$m->get_ok('/');
use utf8;
Encode::_utf8_on($m->{content});
$m->title_is('登入', 'Page title properly translated to chinese');
$m->content_contains('密碼','Password properly translated');
