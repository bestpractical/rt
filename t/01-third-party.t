use strict;
use warnings;

use Test::More;
plan skip_all => 'YAML::Tiny is not installed' unless eval { require YAML::Tiny };

use IPC::Run3;

my $script = 'devel/tools/generate-third-party-readme';

my ( $stdout, $stderr );
run3 [ $script, '--check' ], \undef, \$stdout, \$stderr;
my $exit = $? >> 8;

is( $exit, 0,
    "devel/third-party/README is in sync with per-library metadata.yml files"
) or diag $stderr;

done_testing();
