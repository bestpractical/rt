#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use RT::FM::Test;

use RT;
ok(RT::LoadConfig);

use File::Find;
File::Find::find({wanted => \&wanted}, 'lib');
sub wanted { /^.*\.pm\z/s && $_ !~ /Overlay/ && require_ok($_) };


