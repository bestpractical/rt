#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { require 't/utils.pl' }

use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");
ok ($RT::SystemUser->Id, "The systemuser exists");

use File::Find;
File::Find::find({wanted => \&wanted}, 't/autogen');
sub wanted { /^autogen.*\.t\z/s && require $_;}

File::Find::find({wanted => \&wanted_regression}, 't/regression');
sub wanted_regression { /^.*\.t\z/s  && require $_; }

