#!perl
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);

require RT;
$RT::PluginPath = abs_path(dirname($0)).'/_plugins';
$RT::LocalPluginPath = abs_path(dirname($0)).'/_plugins_null';

use RT::Test nodb => 1, tests => 2;

my $plugins = RT::Plugin->AvailablePlugins;
is_deeply( [ sort keys %$plugins ], [qw(Hello World)]);
my $hello = $plugins->{Hello};
is($hello->BasePath, "$RT::PluginPath/Hello");
