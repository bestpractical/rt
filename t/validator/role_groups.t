use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );

RT::Test->db_is_valid;

my $groups_table = RT::Group->can('QuotedTableName') ? RT::Group->QuotedTableName('Groups') : 'Groups';

$RT::Handle->dbh->do("DELETE FROM $groups_table where Domain IN ('RT::Queue-Role', 'RT::Ticket-Role')");
DBIx::SearchBuilder::Record::Cachable->FlushCache;

for my $object ( $ticket, $ticket->QueueObj ) {
    for my $type (qw/Requestor AdminCc Cc Owner/) {
        ok( !$object->RoleGroup($type)->id, "Deleted group $type for " . ref $object );
    }
}

my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
isnt( $ecode, 0, 'non-zero exit code' );

like( $res, qr/Queues references a nonexistent record in Groups/,  'Found/Fixed error of Queues <-> Role Groups' );
like( $res, qr/Tickets references a nonexistent record in Groups/, 'Found/Fixed error of Tickets <-> Role Groups' );

RT::Test->db_is_valid;

for my $object ( $ticket, $ticket->QueueObj ) {
    for my $type (qw/Requestor AdminCc Cc Owner/) {
        ok( $object->RoleGroup($type)->id, "Recreated group $type for " . ref $object );
    }
}

diag "Test inconsistent owner group member of merged tickets";
my $root           = RT::Test->load_or_create_user( Name => 'root' );
my $nobody         = RT->Nobody->Id;
my $ticket_2       = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket 2', Owner => $root->Id );
my $ticket_2_id    = $ticket_2->Id;
my $owner_group_id = $ticket_2->RoleGroup('Owner')->Id;
$RT::Handle->dbh->do("UPDATE GroupMembers SET MemberId=$nobody WHERE GroupId=$owner_group_id");
my ( $ret, $msg ) = $ticket_2->MergeInto( $ticket->Id );
ok( $ret, $msg );

( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
isnt( $ecode, 0, 'non-zero exit code' );

like(
    $res,
    qr/The owner of ticket #$ticket_2_id is inconsistent/,
    'Found/Fixed error of owner group member of merged ticket'
);
RT::Test->db_is_valid;
$ticket_2->LoadByCols( id => $ticket_2_id );
is( $ticket_2->RoleGroup('Owner')->UserMembersObj->First->id, $root->id, 'Fixed owner group member of merged ticket' );

done_testing;
