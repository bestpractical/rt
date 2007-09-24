#!/usr/bin/perl

use warnings;
use strict;

use RT::Test; use Test::More tests => 7;

use RT;




# This tiny little test script triggers an interaction bug between DBD::Oracle 1.16, SB 1.15 and RT 3.4

use_ok('RT::Model::Template');
my $template = RT::Model::Template->new($RT::SystemUser);

isa_ok($template, 'RT::Model::Template');
my ($val,$msg) = $template->create(Queue => 1,
                  Name => 'InsertTest',
                  Content => 'This is template content');
ok($val,$msg);
is($template->Name, 'InsertTest');
is($template->Content, 'This is template content', "We Created the object right");
($val, $msg) = $template->set_Content( 'This is new template content');
ok($val,$msg);
is($template->Content, 'This is new template content', "We managed to _set_ the content");
