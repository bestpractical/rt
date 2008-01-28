#!/usr/bin/perl

use warnings;
use strict;

use RT::Test; use Test::More tests => 7;

use RT;




# This tiny little test script triggers an interaction bug between DBD::Oracle 1.16, SB 1.15 and RT 3.4

use_ok('RT::Model::Template');
my $template = RT::Model::Template->new(current_user => RT->system_user);

isa_ok($template, 'RT::Model::Template');
my ($val,$msg) = $template->create(Queue => 1,
                  name => 'InsertTest',
                  Content => 'This is template content');
ok($val,$msg);
is($template->name, 'InsertTest');
is($template->content, 'This is template content', "We Created the object right");
($val, $msg) = $template->set_content( 'This is new template content');
ok($val,$msg);
is($template->content, 'This is new template content', "We managed to _set_ the content");
