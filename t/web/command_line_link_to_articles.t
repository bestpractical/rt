use strict;
use warnings;
use Test::Expect;
use RT::Test tests => 12, actual_server => 1;

my $class = RT::Class->new( RT->SystemUser );
my ( $class_id, $msg ) = $class->Create( Name => 'foo' );
ok( $class_id, $msg );

my $article = RT::Article->new( RT->SystemUser );
( my $article_id, $msg ) =
  $article->Create( Class => 'foo', Summary => 'article summary' );
ok( $article_id, $msg );

my ( $baseurl, $m ) = RT::Test->started_ok;
my $rt_tool_path = "$RT::BinPath/rt";

$ENV{'RTUSER'}   = 'root';
$ENV{'RTPASSWD'} = 'password';
$RT::Logger->debug(
    "Connecting to server at " . RT->Config->Get('WebBaseURL') );
$ENV{'RTSERVER'} = RT->Config->Get('WebBaseURL');
$ENV{'RTDEBUG'}  = '1';
$ENV{'RTCONFIG'} = '/dev/null';

expect_run(
    command => "$rt_tool_path shell",
    prompt  => 'rt> ',
    quit    => 'quit',
);
expect_send( q{create -t ticket set subject='new ticket'},
    "creating a ticket..." );

expect_like( qr/Ticket \d+ created/, "created the ticket" );
expect_handle->before() =~ /Ticket (\d+) created/;
my $ticket_id = $1;
expect_send(
    "link $ticket_id RefersTo a:$article_id",
    "link $ticket_id RefersTo a:$article_id"
);
expect_like( qr/Created link $ticket_id RefersTo a:$article_id/,
    'created link' );
expect_send( "show -s ticket/$ticket_id/links", "show ticket links" );
expect_like( qr|RefersTo: fsck\.com-article://example\.com/article/$article_id|,
    "found new created link" );

expect_quit();

