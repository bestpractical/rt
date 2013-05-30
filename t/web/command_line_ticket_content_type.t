use strict;
use warnings;
use Test::Expect;
use RT::Test tests => 22, actual_server => 1;
my ( $baseurl, $m ) = RT::Test->started_ok;
$m->login();

my $rt_tool_path = "$RT::BinPath/rt";

$ENV{'RTUSER'}   = 'root';
$ENV{'RTPASSWD'} = 'password';
$ENV{'RTSERVER'} = RT->Config->Get('WebBaseURL');
$ENV{'RTCONFIG'} = '/dev/null';

# create a ticket
expect_run(
    command => "$rt_tool_path shell",
    prompt  => 'rt> ',
    quit    => 'quit',
);

for my $content_type ( 'text/plain', 'text/html' ) {
    expect_send(
        qq{create -t ticket -ct $content_type set subject='new ticket' text=foo},
        "creating a ticket with content-type $content_type"
    );

    expect_like( qr/Ticket \d+ created/, "created the ticket" );
    expect_handle->before() =~ /Ticket (\d+) created/;
    my $id = $1;
    ok( $id, "got ticket $id" );

    $m->goto_ticket($id);
    $m->follow_link_ok( { text => 'with headers', n => 1 } );
    $m->content_contains( "Content-Type: $content_type", 'content-type' );

    expect_send(
        qq{comment ticket/$id -ct $content_type -m bar},
        "commenting a ticket with content-type $content_type"
    );
    expect_like( qr/Comments added/, "commented the ticket" );

    $m->goto_ticket($id);
    $m->follow_link_ok( { text => 'with headers', n => 2 } );
    $m->content_contains( "Content-Type: $content_type", 'content-type' );
}

expect_quit();
1;    # needed to avoid a weird exit value from expect_quit
