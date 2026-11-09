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
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in CustomFields/,
        'Found/Fixed error of Transactions <-> CustomFields'
    );
    RT::Test->db_is_valid;
}

# CustomField value references
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'bar',
        Queue => 0,
        Type  => 'FreeformSingle',
    );

    my @value_ids;
    for my $value (qw/value1 value2 value3/) {
        my ( $ret, $msg ) = $ticket->AddCustomFieldValue( Field => $cf, Value => $value );
        ok( $ret, $msg );
        push @value_ids, $ret;
    }

    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type',  VALUE => 'CustomField' );
    $txns->Limit( FIELD => 'Field', VALUE => $cf->id );
    $txns->OrderBy( FIELD => 'id' );
    my @txn_ids = map { $_->id } @{ $txns->ItemsArrayRef };
    is( scalar @txn_ids, 3, 'Got 3 custom field transactions' );
    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM ObjectCustomFieldValues where id=" . $value_ids[0] );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in ObjectCustomFieldValues\s+NewReference => '$value_ids[0]'/,
        'Found/Fixed error of Transactions.NewReference <-> ObjectCustomFieldValues'
    );
    like(
        $res,
        qr/Transactions references a nonexistent record in ObjectCustomFieldValues\s+OldReference => '$value_ids[0]'/,
        'Found/Fixed error of Transactions.OldReference <-> ObjectCustomFieldValues'
    );
    RT::Test->db_is_valid;

    for my $id ( @txn_ids[ 0, 1 ] ) {
        my $txn = RT::Transaction->new( RT->SystemUser );
        $txn->Load($id);
        ok( !$txn->id, "Transaction #$id referencing the deleted value is deleted" );
    }
    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load( $txn_ids[2] );
    is( $txn->id, $txn_ids[2], "Transaction #$txn_ids[2] with valid references is kept" );
}

# Configuration references
{
    my $config = RT::Configuration->new( RT->SystemUser );
    my ( $ret, $msg ) = $config->Create( Name => 'DefaultSummaryRows', Content => 10 );
    ok( $ret, $msg );
    my $old_config_id = $config->id;

    ( $ret, $msg ) = $config->SetContent(20);
    ok( $ret, $msg );

    my $txns = RT::Transactions->new( RT->SystemUser );
    $txns->Limit( FIELD => 'Type',  VALUE => 'SetConfig' );
    $txns->Limit( FIELD => 'Field', VALUE => 'DefaultSummaryRows' );
    $txns->OrderBy( FIELD => 'id' );
    my @txn_ids = map { $_->id } @{ $txns->ItemsArrayRef };
    is( scalar @txn_ids, 2, 'Got 2 config transactions' );
    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Configurations where id=$old_config_id" );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in Configurations\s+NewReference => '$old_config_id'/,
        'Found/Fixed error of Transactions.NewReference <-> Configurations'
    );
    like(
        $res,
        qr/Transactions references a nonexistent record in Configurations\s+OldReference => '$old_config_id'/,
        'Found/Fixed error of Transactions.OldReference <-> Configurations'
    );
    RT::Test->db_is_valid;

    for my $id (@txn_ids) {
        my $txn = RT::Transaction->new( RT->SystemUser );
        $txn->Load($id);
        ok( !$txn->id, "Transaction #$id referencing the deleted config is deleted" );
    }
}

# Attribute references
{
    my $search = RT::Attribute->new( RT->SystemUser );
    my ( $ret, $msg ) = $search->Create(
        Name        => 'SavedSearch',
        Description => 'test search',
        Content     => { Query => 'id > 0' },
        Object      => RT->SystemUser,
    );
    ok( $ret, $msg );

    ( $ret, $msg ) = $search->SetContent( { Query => 'id > 1' } );
    ok( $ret, $msg );

    my $txns = RT::Transactions->new( RT->SystemUser );
    $txns->Limit( FIELD => 'ObjectType',    VALUE => 'RT::Attribute' );
    $txns->Limit( FIELD => 'ObjectId',      VALUE => $search->id );
    $txns->Limit( FIELD => 'ReferenceType', VALUE => 'RT::Attribute' );
    my $txn_id = $txns->First->id;
    my $old_id = $txns->First->OldReference;
    ok( $old_id, 'Got the content history reference' );
    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Attributes where id=$old_id" );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like(
        $res,
        qr/Transactions references a nonexistent record in Attributes\s+OldReference => '$old_id'/,
        'Found/Fixed error of Transactions.OldReference <-> Attributes'
    );
    RT::Test->db_is_valid;

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->Load($txn_id);
    ok( !$txn->id, "Transaction #$txn_id referencing the deleted content history is deleted" );
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
    isnt( $ecode, 0, 'non-zero exit code' );
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
