#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { require 't/utils.pl' }

use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");

use File::Find;
File::Find::find({wanted => \&wanted}, 'lib');
sub wanted { /^.*\.pm\z/s && $_ !~ /Overlay/ && ok(require $_, "Requiring '$_'"); }


