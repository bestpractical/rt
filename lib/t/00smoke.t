#!/usr/bin/perl

use Test::More qw(no_plan);

use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");

use File::Find;
File::Find::find({wanted => \&wanted}, 'lib/');
sub wanted { /^*\.pm\z/s && ok(require $_, "Requiring '$_'"); }


