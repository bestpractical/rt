#!perl
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);

require RT;
$RT::PluginPath = abs_path(dirname($0)).'/_plugins';

use RT::Test nodb => 1, tests => 5;

is_deeply([RT->PluginDirs('lib')], []);
ok(!grep { $_ eq "$RT::PluginPath/Hello/lib" } @INC);;
RT->Config->Set('Plugins',qw(Hello));
RT->InitPluginPaths;

ok(grep { $_ eq "$RT::PluginPath/Hello/lib" } @INC);;

is_deeply([RT->PluginDirs('lib')], ["$RT::PluginPath/Hello/lib"]);

require RT::Interface::Web::Handler;


is_deeply({RT::Interface::Web::Handler->DefaultHandlerArgs}->{comp_root}[1],
          ['plugin-Hello', $RT::PluginPath.'/Hello/html']);


