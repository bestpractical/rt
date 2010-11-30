#!perl
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath);

BEGIN {
    require RT;
    require RT::Generated;
    require File::Temp;

    # bootstrap a fake LocalLibPath
    my $dir_name = File::Spec->rel2abs('t/tmp');
    mkpath( $dir_name );
    $RT::LocalLibPath =  File::Temp::tempdir( CLEANUP => 1);

    unshift @INC, abs_path($RT::LocalLibPath);
    $RT::LocalPluginPath = abs_path(dirname($0)).'/_plugins';
}

use RT::Test nodb => 1, tests => 9;

is_deeply([RT->PluginDirs('lib')], []);
ok(!grep { $_ eq "$RT::LocalPluginPath/Hello/lib" } @INC);;
RT->Config->Set('Plugins',qw(Hello));

RT->ProbePlugins(1);
RT->UnloadPlugins;
RT->Plugins;

ok(grep { $_ eq "$RT::LocalPluginPath/Hello/lib" } @INC);;

is_deeply([RT->PluginDirs('lib')], ["$RT::LocalPluginPath/Hello/lib"], 'plugin lib dir found');

require RT::Interface::Web::Handler;

is_deeply({RT::Interface::Web::Handler->DefaultHandlerArgs}->{comp_root}[1],
          ['plugin-Hello', $RT::LocalPluginPath.'/Hello/html']);

# reset
RT->Config->Set('Plugins',qw());
RT->ProbePlugins(1);
RT->UnloadPlugins;

ok(!grep { $_ eq "$RT::LocalPluginPath/Hello/lib" } @INC);
is_deeply(
    [map { $_->[0] }
         @{ {RT::Interface::Web::Handler->DefaultHandlerArgs}->{comp_root} }],
    [qw(local standard)]
);


my %inc_seem = map { $_ => 1 } @INC;
# reset
RT->Config->Set('Plugins',qw(Hello World));
RT->ProbePlugins(1);
RT->UnloadPlugins;
RT->Plugins;

is_deeply([@INC[0..2]],
          [map { abs_path($_) }
               $RT::LocalLibPath,
               "$RT::LocalPluginPath/Hello/lib",
               "$RT::LocalPluginPath/World/lib"]);

is_deeply(
    [map { $_->[0] }
         @{ {RT::Interface::Web::Handler->DefaultHandlerArgs}->{comp_root} }],
    [qw(local plugin-Hello plugin-World standard)]
);

