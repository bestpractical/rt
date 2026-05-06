use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket(
    Queue       => 'General',
    Subject     => 'test scrubber',
    ContentType => 'text/html',
    Content     => <<'EOF' );
Image start
<img src="https://example.com/test.png">
Image end
EOF

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

$m->goto_ticket( $ticket->Id );

$m->content_lacks('<img src="https://example.com/test.png">', 'Remote images are not shown by default');

my $config = RT::Configuration->new( RT->SystemUser );
my ( $ret, $msg ) = $config->Create(
    Name    => 'ShowRemoteImages',
    Content => 1,
);
ok( $ret, 'Updated config' );

$m->reload;
$m->content_contains('<img src="https://example.com/test.png">', 'Remote images are shown with ShowRemoteImages=1');

done_testing;
