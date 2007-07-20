#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 7;

require "t/rtir-test.pl";

my $agent = default_agent();


$agent->follow_link_ok({text => 'Incident Reports', n => "1"}, "Followed 'Incident Reports' link");
$agent->follow_link_ok({text => "New Report", n => "1"}, "Followed 'New Report' link");

$agent->content_unlike(qr{<select name="Object-RT::Ticket--CustomField-20-Values" id="Object-RT::Ticket--CustomField-20-Values"\s*size="5"\s*>}, "Select box does not appear");
$agent->content_like(qr{Age: .*}, "Found Age text (not a select box)");
