use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->db_is_valid;

# ACE pointing to invalid Principal
{
    my $rv = $RT::Handle->dbh->do( "INSERT INTO ACL(PrincipalId, PrincipalType, RightName, ObjectType, ObjectId) VALUES(?, ?, ?, ?, ?)",
        undef,
        1024*1024*1024, 'User', 'ARight', 'RT::Transaction', 1,
    );
    ok( $rv, 'inserted' );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/ACL references a nonexistent record in Principals/,
        'Found/Fixed error of Transactions <-> CustomFields'
    );
    RT::Test->db_is_valid;
}

done_testing();