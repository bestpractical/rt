#!/usr/bin/perl

use warnings;
use strict;


use RT;
use RT::Test tests => 7;



# This tiny little test script triggers an interaction bug between DBD::Oracle 1.16, SB 1.15 and RT 3.4

use_ok('RT::Template');
my $template = RT::Template->new(RT->SystemUser);

isa_ok($template, 'RT::Template');
my ($val,$msg) = $template->Create(Queue => 1,
                  Name => 'InsertTest',
                  Content => 'This is template content');
ok($val,$msg);
is($template->Name, 'InsertTest');
is($template->Content, 'This is template content', "We created the object right");
($val, $msg) = $template->SetContent( 'This is new template content');
ok($val,$msg);
is($template->Content, 'This is new template content', "We managed to _Set_ the content");
