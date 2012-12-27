
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder nodb => 1, tests => 28;
my $test = "RT::Test::Shredder";

my @PLUGINS = sort qw(Attachments Base Objects SQLDump Summary Tickets Users);

use_ok('RT::Shredder::Plugin');
{
    my $plugin = RT::Shredder::Plugin->new;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my %plugins = $plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # test ->List as class method
    my %plugins = RT::Shredder::Plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # reblessing on LoadByName
    foreach (@PLUGINS) {
        my $plugin = RT::Shredder::Plugin->new;
        isa_ok($plugin, 'RT::Shredder::Plugin');
        my ($status, $msg) = $plugin->LoadByName( $_ );
        ok($status, "loaded plugin by name") or diag("error: $msg");
        isa_ok($plugin, "RT::Shredder::Plugin::$_" );
    }
}
{ # error checking in LoadByName
    my $plugin = RT::Shredder::Plugin->new;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my ($status, $msg) = $plugin->LoadByName;
    ok(!$status, "not loaded plugin - empty name");
    ($status, $msg) = $plugin->LoadByName('Foo');
    ok(!$status, "not loaded plugin - not exist");
}

