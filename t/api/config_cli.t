use strict;
use warnings;
use RT::Test tests => undef, config => q{
Set($DefaultQueue, 1); # General
};
use IPC::Run3 'run3';

my $sbin = $RT::SbinPath;

sub run_rt_config {
    my @args = @_;
    my ( $stdout, $stderr ) = ( '', '' );
    run3( [ "$sbin/rt-config", @args ], \undef, \$stdout, \$stderr );
    my $exit = $? >> 8;
    return ( $stdout, $stderr, $exit );
}

diag "show a scalar config";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'show', 'DefaultQueue' );
    is( $exit, 0, 'show DefaultQueue exited 0' );
    like( $stdout, qr/^1$/, 'shows default queue value' );
}

diag "show a reference config in perl format";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'show', 'PriorityAsString' );
    is( $exit, 0, 'show PriorityAsString in perl format exited 0' );
    like( $stdout, qr/\{/, 'perl format has braces' );
}

diag "show a reference config in json format";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'show', 'PriorityAsString', '--format', 'json' );
    is( $exit, 0, 'show PriorityAsString in json format exited 0' );
    like( $stdout, qr/\{/, 'json format has braces' );
}

diag "show an unknown config";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'show', 'SomeUnknownOption' );
    is( $exit, 1, 'show SomeUnknownOption exited 1' );
    like(
        $stderr,
        qr/No such configuration option: SomeUnknownOption/,
        'unknown config error message includes config name'
    );
}

diag "edit a scalar config with --value";
{
    my $test_queue = RT::Test->load_or_create_queue( Name => 'Test' );
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'edit', 'DefaultQueue', '--value', $test_queue->Id );
    is( $exit, 0, 'edit DefaultQueue exited 0' );

    my ($out2) = run_rt_config( 'show', 'DefaultQueue' );
    chomp $out2;
    is( $out2, $test_queue->Id, 'show reflects the edited value' );
}

diag "edit with no change";
{
    # The previous test stored test_queue->Id in the database.
    # A fresh rt-config process will see the db value, so pass it again.
    my ($show_out) = run_rt_config( 'show', 'DefaultQueue' );
    chomp $show_out;

    my ( $stdout, $stderr, $exit ) = run_rt_config( 'edit', 'DefaultQueue', '--value', $show_out );
    is( $exit, 0, 'edit DefaultQueue with no change exited 0' );
    like( $stdout, qr/Nothing changed/, 'nothing changed message' );
}

diag "edit an immutable config";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'edit', 'DatabaseType', '--value', 'mysql' );
    is( $exit, 1, 'edit DatabaseType exited 1' );
    like( $stderr, qr/can be modified only in config file/, 'immutable error message' );
}

diag "edit an unknown config";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'edit', 'SomeUnknownOption', '--value', 'foo' );
    is( $exit, 1, 'edit SomeUnknownOption exited 1' );
    like( $stderr, qr/No metadata found for SomeUnknownOption/, 'unknown config error message includes config name' );
}

diag "edit a reference config with invalid json";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'edit', 'PriorityAsString', '--value', '{bad json' );
    is( $exit, 1, 'edit PriorityAsString with invalid json exited 1' );
    like( $stderr, qr/Invalid JSON for PriorityAsString/, 'invalid json error message' );
}

diag "reset a config";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'reset', 'DefaultQueue' );
    is( $exit, 0, 'reset DefaultQueue exited 0' );

    my ($out2) = run_rt_config( 'show', 'DefaultQueue' );
    chomp $out2;
    is( $out2, '1', 'show reflects the file config value after reset' );
}

diag "reset a config not set in database";
{
    my ( $stdout, $stderr, $exit ) = run_rt_config( 'reset', 'DefaultQueue' );
    is( $exit, 1, 'reset DefaultQueue not in database exited 1' );
    like( $stderr, qr/is not set in database/, 'not in database error message' );
}

done_testing;
