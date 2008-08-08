#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More tests => 7;
use RT::Test;

my ($baseurl, $m) = RT::Test->started_ok;
$m->get_ok('/');
$m->title_is('Login');

$m->get_ok('/', { 'Accept-Language' => 'x-klingon' });
$m->title_is('Login', 'unavailable language fallback to en');

$m->add_header('Accept-Language' => 'zh-tw,zh;q=0.8,en-gb;q=0.5,en;q=0.3');
$m->get_ok('/');
use utf8;
use Devel::Peek;
Encode::_utf8_on($m->{content});
TODO: {
    local $TODO = 'login page should be l10n';
    $m->title_is('登入');
};

