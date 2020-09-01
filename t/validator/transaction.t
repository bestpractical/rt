use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->db_is_valid;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );

# CustomField
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'foo',
        Queue => 0,
        Type  => 'FreeformSingle',
    );
    $ticket->AddCustomFieldValue( Field => $cf, Value => 'value1' );
    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM CustomFields where id=" . $cf->id );

    # TODO validator can't fix ObjectCustomFieldValues if CustomField is gone,
    # fix it manually here.
    $RT::Handle->dbh->do( "DELETE FROM ObjectCustomFieldValues where CustomField=" . $cf->id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' ) or diag ($res);
    like(
        $res,
        qr/Transactions references a nonexistent record in CustomFields/,
        'Found/Fixed error of Transactions <-> CustomFields'
    );
    RT::Test->db_is_valid;
}

# Watcher
{
    my $user = RT::Test->load_or_create_user( Name => 'foo', );
    $user->PrincipalObj->GrantRight( Right => 'SuperUser' );

    my ( $ret, $msg ) = $ticket->SetOwner( $user );
    ok( $ret, $msg );

    # we don't test Tickets table here, so keep it in good status.
    ( $ret, $msg ) = $ticket->SetOwner( 'root' );
    ok( $ret, $msg );

    for my $type ( qw/Requestor AdminCc Cc/ ) {
        ( $ret, $msg ) = $ticket->AddWatcher( Type => $type, PrincipalId => $user->id );
        ok( $ret, $msg );

        ( $ret, $msg ) = $ticket->DeleteWatcher( Type => $type, PrincipalId => $user->id );
        ok( $ret, $msg );
    }

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Users where id=" . $user->id );
    $RT::Handle->dbh->do( "DELETE FROM Principals where id=" . $user->PrincipalId );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' ) or diag ($res);
    like(
        $res,
        qr/Transactions references a nonexistent record in Users/,
        'Found/Fixed error of Transactions <-> Users'
    );
    like(
        $res,
        qr/Transactions references a nonexistent record in Principals/,
        'Found/Fixed error of Transactions <-> Principals'
    );

    RT::Test->db_is_valid;
}

# Queue
{
    my $queue = RT::Test->load_or_create_queue( Name => 'foo', );

    my ( $ret, $msg ) = $ticket->SetQueue( $queue->id );
    ok( $ret, $msg );

    # we don't test Tickets table here, so keep it in good status.
    ( $ret, $msg ) = $ticket->SetQueue( 'General' );
    ok( $ret, $msg );

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Queues where id=" . $queue->id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in Queues/,
        'Found/Fixed error of Transactions <-> Queues'
    );
    RT::Test->db_is_valid;
}

# Reminder
{
    my ( $reminder_id ) = $ticket->Reminders->Add(
        Subject => 'TestReminder',
        Owner   => 'root',
    );
    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Tickets where id=$reminder_id" );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in Tickets/,
        'Found/Fixed error of Transactions <-> Tickets'
    );
    RT::Test->db_is_valid;
}

done_testing;
