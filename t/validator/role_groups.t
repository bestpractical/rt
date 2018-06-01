use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );

RT::Test->db_is_valid;

$RT::Handle->dbh->do( "DELETE FROM Groups where Domain='RT::Ticket-Role' AND Instance=" . $ticket->id );
DBIx::SearchBuilder::Record::Cachable->FlushCache;

for my $type ( qw/Requestor AdminCc Cc Owner/ ) {
    ok( !$ticket->RoleGroup( $type )->id, "Deleted group $type" );
}

my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
isnt( $ecode, 0, 'non-zero exit code' );

like( $res, qr/Tickets references a nonexistent record in Groups/, 'Found/Fixed error of Tickets <-> Role Groups' );

RT::Test->db_is_valid;

for my $type ( qw/Requestor AdminCc Cc Owner/ ) {
    ok( $ticket->RoleGroup( $type )->id, "Recreated group $type" );
}

done_testing;
