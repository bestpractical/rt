use strict;
use warnings;

use RT::Test tests => 8;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

use File::Spec;
use File::Temp 'tempdir';

my $tmpdir = tempdir( DIR => $RT::VarPath, CLEANUP => 1 );
my $file = File::Spec->catfile( $tmpdir, 0 );
open my $fh, '>', $file or die $!;
print $fh 'foobar';
close $fh;

$m->get_ok( '/Ticket/Create.html?Queue=1' );

$m->submit_form(
    form_number => 3,
    fields => { Subject => 'test att 0', Content => 'test', Attach => $file },
);
$m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
$m->follow_link_ok( { text => 'Download 0' } );
$m->content_contains( 'foobar', 'file content' );
