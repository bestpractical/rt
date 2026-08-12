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

diag "Codes are loaded case sensitively";
{
    $RT::Handle->LogSQLStatements(1);
    $RT::Handle->ClearSQLStatementLog;

    my $shortener = RT::Shortener->new( RT->SystemUser );
    $shortener->LoadByCode('dc4195253b');
    is( $shortener->Id, $s->Id, 'loaded by code' );

    my ($statement) = grep { /\bShorteners\b/i } map { $_->[1] } $RT::Handle->SQLStatementLog;
    like( $statement, qr/WHERE Code = \?/, 'Code is compared as is, so the index on Code can be used' );

    $RT::Handle->LogSQLStatements(0);

    if ( $RT::Handle->CaseSensitive ) {
        $shortener = RT::Shortener->new( RT->SystemUser );
        $shortener->LoadByCode('DC4195253B');
        ok( !$shortener->Id, 'uppercased code is not loaded' );
    }
}

done_testing();
