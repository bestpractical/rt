use strict;
use warnings;

use Test::MockTime qw(set_fixed_time restore_time);
set_fixed_time("2020-01-01T00:00:00Z");

use RT::Test tests => undef;

use_ok('RT::Shorteners');

my %id;
my $s = RT::Shortener->new( RT->SystemUser );
my ( $ret, $msg ) = $s->Create( Content => 'Query=id<10&Rows=50' );
ok( $ret, $msg );
$id{old} = $s->Id;

( $ret, $msg ) = $s->Create( Content => 'Query=id<20&Rows=50', Permanent => 1 );
ok( $ret, $msg );
$id{permanent} = $s->Id;

restore_time();

( $ret, $msg ) = $s->Create( Content => 'Query=id<30&Rows=50' );
ok( $ret, $msg );
$id{new} = $s->Id;

my $items = RT::Shorteners->new( RT->SystemUser );
$items->UnLimit;
is( $items->Count, 3, 'Found all shorteners' );

$items->CleanSlate;
$items->Limit( FIELD => 'Content', VALUE => 'Query=id<10&Rows=50' );

is( $items->Count,          1,                     'Found one shortener' );
is( $items->First->Content, 'Query=id<10&Rows=50', 'Found the shortener' );

( $ret, $msg ) = RT::Test->run_and_capture(
    command => $RT::SbinPath . '/rt-clean-shorteners',
    older   => '1Y',
    verbose => 1,
);
is( $ret >> 8, 0, 'rt-clean-shorteners exited normally' );
like( $msg, qr/deleted 1 shortener/, 'Deleted one shortener' );

$s->Load( $id{old} );
ok( !$s->Id, 'The old one is deleted' );
$s->Load( $id{new} );
ok( $s->Id, 'The new one is not deleted' );

( $ret, $msg ) = RT::Test->run_and_capture(
    command => $RT::SbinPath . '/rt-clean-shorteners',
    older   => '0H',
    verbose => 1,
);
is( $ret >> 8, 0, 'rt-clean-shorteners exited normally' );
like( $msg, qr/deleted 1 shortener/, 'Deleted one shortener' );

$s->Load( $id{new} );
ok( !$s->Id, 'The new one is deleted' );

$s->Load( $id{permanent} );
ok( $s->Id, 'The permanent one is not deleted' );

done_testing();
