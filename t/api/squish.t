use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 10;

use RT::Squish;
use File::Temp 'tempfile';

my ( $fh1, $file1 ) = tempfile( 'rttestXXXXXX', UNLINK => 1, TMPDIR => 1 );
print $fh1 "this is file1\n";
close $fh1;
my ( $fh2, $file2 ) = tempfile( 'rttestXXXXXX', UNLINK => 1, TMPDIR => 1 );
print $fh2 "this is file2\n";
close $fh2;

my $squish = RT::Squish->new( Name => 'foo', Files => [ $file1, $file2 ]  );
for my $method ( qw/Name Files Content ModifiedTime Key/ ) {
    can_ok($squish, $method);
}

is( $squish->Name, 'foo', 'Name' );
is_deeply( $squish->Files, [ $file1, $file2 ], 'Files' );
is( $squish->Content, "this is file1\nthis is file2\n", 'Content' );
like( $squish->Key, qr/[a-f0-9]{32}/, 'Key is like md5' );
ok( (time()-$squish->ModifiedTime) <= 2, 'ModifiedTime' );

