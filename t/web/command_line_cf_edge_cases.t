use strict;
use warnings;
use Test::Expect;
use RT::Test tests => 100, actual_server => 1;
my ( $baseurl, $m ) = RT::Test->started_ok;

my $rt_tool_path = "$RT::BinPath/rt";

$ENV{'RTUSER'}   = 'root';
$ENV{'RTPASSWD'} = 'password';
$ENV{'RTSERVER'} = RT->Config->Get('WebBaseURL');
$ENV{'RTDEBUG'}  = '1';
$ENV{'RTCONFIG'} = '/dev/null';

my @cfs = (
    'foo=bar',  'foo.bar', 'foo:bar', 'foo bar',
    'foo{bar}', 'foo-bar', 'foo()bar',
);
for my $name (@cfs) {
    RT::Test->load_or_create_custom_field(
        Name      => $name,
        Type      => 'Freeform',
        MaxValues => 1,
        Queue     => 0,
    );
}

expect_run(
    command => "$rt_tool_path shell",
    prompt  => 'rt> ',
    quit    => 'quit',
);

# create a ticket
for my $name (@cfs) {
    expect_send(
qq{create -t ticket set subject='test cf $name' 'CF.{$name}=foo:b a.r=baz'},
        "creating a ticket for cf $name"
    );

    expect_handle->before() =~ /Ticket (\d+) created/;
    my $ticket_id = $1;

    expect_send( "show ticket/$ticket_id -f 'CF.{$name}'",
        'checking new value' );
    expect_like( qr/CF\.\Q{$name}\E: foo:b a\.r=baz/i, 'verified change' );

    expect_send( "edit ticket/$ticket_id set 'CF.{$name}=bar'",
        "changing cf $name to bar" );
    expect_like( qr/Ticket $ticket_id updated/, 'changed cf' );
    expect_send( "show ticket/$ticket_id -f 'CF.{$name}'",
        'checking new value' );
    expect_like( qr/CF\.\Q{$name}\E: bar/i, 'verified change' );

    expect_send(
qq{create -t ticket set subject='test cf $name' 'CF-$name=foo:b a.r=baz'},
        "creating a ticket for cf $name"
    );
    expect_handle->before() =~ /Ticket (\d+) created/;
    $ticket_id = $1;

    expect_send( "show ticket/$ticket_id -f 'CF-$name'", 'checking new value' );
    if ( $name eq 'foo=bar' ) {
        expect_like( qr/CF\.\Q{$name}\E: $/mi,
            "can't use = in cf name with old style" );
    }
    else {
        expect_like( qr/CF\.\Q{$name}\E: foo:b a\.r=baz/i, 'verified change' );
        expect_send( "edit ticket/$ticket_id set 'CF-$name=bar'",
            "changing cf $name to bar" );
        expect_like( qr/Ticket $ticket_id updated/, 'changed cf' );
        expect_send( "show ticket/$ticket_id -f 'CF-$name'",
            'checking new value' );
        expect_like( qr/CF\.\Q{$name}\E: bar/i, 'verified change' );
    }
}

my @invalid = ('foo,bar');
for my $name (@invalid) {
    expect_send(
        qq{create -t ticket set subject='test cf $name' 'CF.{$name}=foo'},
        "creating a ticket for cf $name" );
    expect_like( qr/You shouldn't specify objects as arguments to create/i,
        '$name is not a valid cf name' );
}

expect_quit();
