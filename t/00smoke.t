#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use RT::FM::Test qw(no_plan);

use RT;
ok(RT::LoadConfig);

use File::Find;
File::Find::find({wanted => \&wanted}, 'lib');
sub wanted { /^.*\.pm\z/s && $_ !~ /Overlay/ && ok(require $_, "Requiring '$_'"); }


