use strict;
use warnings;

use Test::More;
use Test::Pod;
all_pod_files_ok(
    all_pod_files("lib","devel","docs","etc","bin","sbin"),
    <docs/UPGRADING*>,
    <devel/docs/UPGRADING*>,
);
