#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 5;

RT->Config->Set(StatementLog => 1);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

$m->get_ok("/Admin/Tools/Queries.html");
$m->text_contains("Executed SQL query at", "stack traces");
$m->text_contains("SELECT * FROM Users WHERE LOWER(Name) = LOWER('root')", "we interpolate bind params");

