#!/usr/bin/perl

use Test::More qw(no_plan);

use lib "/opt/rt3/lib";
use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");
ok ($RT::SystemUser->Id, "The systemuser exists");

use File::Find;
File::Find::find({wanted => \&wanted}, 'lib/t/autogen');
sub wanted { /^autogen.*\.t\z/s && require $_; }

File::Find::find({wanted => \&wanted_regression}, 'lib/t/regression');
sub wanted_regression { /^*\.t\z/s && require $_; }

