#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 14;

my ($url, $m);

# Enabled by default
{
    ok(RT->Config->ExtraSecurity('Clickjacking'), "RT->Config->ExtraSecurity reports Clickjacking enabled");
    ok(RT->Config->ExtraSecurity('clickjacking'), "RT->Config->ExtraSecurity reports clickjacking enabled");

    ($url, $m) = RT::Test->started_ok;
    $m->get_ok($url);
    $m->content_contains('if (window.top !== window.self) {', "Found the framekiller javascript");
    is $m->response->header('X-Frame-Options'), 'DENY', "X-Frame-Options is set to DENY";

    RT::Test->stop_server;
}

# Disabled
{
    RT->Config->Set('ExtraSecurity' => grep { !/clickjacking/i } RT->Config->Get('ExtraSecurity'));
    ok(!RT->Config->ExtraSecurity('Clickjacking'), "RT->Config->ExtraSecurity reports Clickjacking disabled");
    ok(!RT->Config->ExtraSecurity('clickjacking'), "RT->Config->ExtraSecurity reports clickjacking disabled");

    ($url, $m) = RT::Test->started_ok;
    $m->get_ok($url);
    $m->content_lacks('if (window.top !== window.self) {', "Didn't find the framekiller javascript");
    is $m->response->header('X-Frame-Options'), undef, "X-Frame-Options is not present";
}

