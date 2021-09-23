use strict;
use warnings;

use RT::Test tests => undef;

use_ok('RT::Shortener');

my $s = RT::Shortener->new( RT->SystemUser );
my ( $ret, $msg ) = $s->Create( Content => 'Query=id<10&Rows=50' );
ok( $ret, $msg );

is( $s->Content, 'Query=id<10&Rows=50', 'Content' );
is( $s->Code,    'dc4195253b',          'Code is auto generated' );
for my $field (qw/Creator LastUpdatedBy LastAccessedBy/) {
    is( $s->$field, RT->SystemUser->Id, "$field" );
}

for my $field (qw/Created LastUpdated LastAccessed/) {
    ok( $s->$field, "$field" );
}

( $ret, $msg ) = $s->SetPermanent(1);
ok( $ret, $msg );

done_testing();
