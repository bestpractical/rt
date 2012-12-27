use strict;
use warnings;
use File::Spec ();
use Test::Expect;
use RT::Test tests => 21, actual_server => 1;
my ($baseurl, $m) = RT::Test->started_ok;
my $rt_tool_path = "$RT::BinPath/rt";

$ENV{'RTUSER'} = 'root';
$ENV{'RTPASSWD'} = 'password';
$RT::Logger->debug("Connecting to server at ".RT->Config->Get('WebBaseURL'));
$ENV{'RTSERVER'} =RT->Config->Get('WebBaseURL') ;
$ENV{'RTDEBUG'} = '1';
$ENV{'RTCONFIG'} = '/dev/null';

expect_run(
    command => "$rt_tool_path shell",
    prompt => 'rt> ',
    quit => 'quit',
);

expect_send( q{create -t ticket set foo=bar}, "create ticket with unknown field" );
expect_like(qr/foo: Unknown field/, 'foo is unknown field');
expect_like(qr/Could not create ticket/, 'ticket is not created');

expect_send(q{create -t ticket set subject='new ticket' add cc=foo@example.com}, "Creating a ticket...");

expect_like(qr/Ticket \d+ created/, "Created the ticket");
expect_handle->before() =~ /Ticket (\d+) created/;
my $ticket_id = $1;

expect_send("edit ticket/$ticket_id set marge=simpson", 'set unknown field');
expect_like(qr/marge: Unknown field/, 'marge is unknown field');
expect_like(qr/marge: simpson/, 'the value we set for marge is shown too');

expect_send("edit ticket/$ticket_id set homer=simpson", 'set unknown field');
expect_like(qr/homer: Unknown field/, 'homer is unknown field');
expect_like(qr/homer: simpson/, 'the value we set for homer is shown too');

expect_send(
    q{create -t ticket set requestors='foo@example.com, bar@example.com'},
    "create ticket with field 'requestors'" );
expect_like(qr/Ticket \d+ created/, "Created the ticket");
expect_handle->before() =~ /Ticket (\d+) created/;
$ticket_id = $1;
expect_send("show ticket/$ticket_id", 'check requestors');
expect_like(qr/From: (?:foo\@example\.com, bar\@example\.com|bar\@example\.com, foo\@example\.com)/, "requestors are set correctly");

expect_quit();

# you may encounter warning like Use of uninitialized value $ampm
# ... in Time::ParseDate
my @warnings = grep { $_ !~ /\$ampm/ } $m->get_warnings;
is( scalar @warnings, 0, 'no extra warnings' );

1; # needed to avoid a weird exit value from expect_quit
