use strict;
use warnings;

use RT::Test tests => undef, config => 'Set( %FullTextSearch, Enable => 1, Indexed => 0 );';

my ( $bilbo, $frodo )
    = RT::Test->create_tickets( { Queue => 'General' }, { Subject => 'Bilbo' }, { Subject => 'Frodo' }, );

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL('ObjectType="RT::Ticket" AND TicketSubject = "Frodo" AND Type="Create"');
is( $txns->Count, 1, 'Found the create txn' );
my $txn = $txns->Next;

my %field_value = (
    ObjectType => 'RT::Ticket',
    ObjectId   => $frodo->id,
    Type       => 'Create',
);

for my $field ( keys %field_value ) {
    is( $txn->$field, $field_value{$field}, $field );
}

$txns->FromSQL('ObjectType="RT::Ticket" AND Type="Create" AND TicketStatus="__Active__"');
is( $txns->Count, 2, 'Found the 2 create txns of active tickets' );

$txns->FromSQL('ObjectType="RT::Ticket" AND Type="Create" AND TicketStatus="__Inactive__"');
is( $txns->Count, 0, 'Found the 0 create txns of inactive tickets' );

ok( $frodo->SetStatus('resolved'), 'Resolved 1 ticket' );
$txns->FromSQL('ObjectType="RT::Ticket" AND Type="Create" AND TicketStatus="__Active__"');
is( $txns->Count, 1, 'Found the 1 create txn of active tickets' );
is( $txns->Next->ObjectId, $bilbo->id, 'Active ticket is bilbo' );

$txns->FromSQL('ObjectType="RT::Ticket" AND Type="Create" AND TicketStatus="__Inactive__"');
is( $txns->Count, 1, 'Found the 1 create txn of inactive tickets' );
is( $txns->Next->ObjectId, $frodo->id, 'Inactive ticket is frodo' );

my $cf_age = RT::Test->load_or_create_custom_field(
    Name  => 'Age',
    Queue => 0,
    Type  => 'FreeformSingle',
);

my $cf_height = RT::Test->load_or_create_custom_field(
    Name  => 'Height',
    Queue => 0,
    Type  => 'FreeformSingle',
);

$bilbo->AddCustomFieldValue( Field => $cf_age, Value => '110' );
$frodo->AddCustomFieldValue( Field => $cf_age, Value => '32' );

$bilbo->AddCustomFieldValue( Field => $cf_age, Value => '111' );
$frodo->AddCustomFieldValue( Field => $cf_age, Value => '33' );

$bilbo->AddCustomFieldValue( Field => $cf_height->id, Value => '3 feets' );
$frodo->AddCustomFieldValue( Field => $cf_height->id, Value => '3 feets' );

$txns->FromSQL('OldCFValue = 110');
is( $txns->Count, 1, 'Found the txns' );
$txn = $txns->Next;
is( $txn->OldValue, 110, 'Old value' );
is( $txn->NewValue, 111, 'New value' );

$txns->FromSQL('NewCFValue = "3 feets"');
is( $txns->Count, 2, 'Found the 2 txns' );
my @txns = @{ $txns->ItemsArrayRef };
is( $txns[0]->OldValue, undef,     'Old value' );
is( $txns[0]->NewValue, '3 feets', 'New value' );
is( $txns[1]->OldValue, undef,     'Old value' );
is( $txns[1]->NewValue, '3 feets', 'New value' );

$txns->FromSQL('ObjectType = "RT::Ticket" AND CFName = "Age"');
is( $txns->Count, 4, 'Found the txns' );
@txns = @{ $txns->ItemsArrayRef };
is( $txns[0]->OldValue, undef, 'Old value' );
is( $txns[0]->NewValue, 110,   'New value' );

is( $txns[1]->OldValue, undef, 'Old value' );
is( $txns[1]->NewValue, 32,    'New value' );

is( $txns[2]->OldValue, 110, 'Old value' );
is( $txns[2]->NewValue, 111, 'New value' );

is( $txns[3]->OldValue, 32, 'Old value' );
is( $txns[3]->NewValue, 33, 'New value' );

my $root = RT::CurrentUser->new( RT->SystemUser );
$root->Load('root');
ok( $root->id, 'Load root' );

$txns = RT::Transactions->new($root);
$txns->FromSQL('Creator = "root"');
is( $txns->Count, 0, 'No txns created by root' );

my $ticket = RT::Ticket->new($root);
$ticket->Load( $bilbo->id );
ok( $ticket->SetStatus('open') );

$txns->FromSQL('Creator = "root"');
is( $txns->Count, 1, 'Found ticket txn created by root' );
$txn = $txns->Next;

is( $txn->ObjectId, $bilbo->id, 'ObjectId' );
is( $txn->Field,    'Status',   'Field' );
is( $txn->Type,     'Status',   'Type' );
is( $txn->OldValue, 'new',      'OldValue' );
is( $txn->NewValue, 'open',     'NewValue' );

$txns->FromSQL('Type = "Correspond"');
is( $txns->Count, 0, 'No correspond txn' );

my ($correspond_txn_id) = $ticket->Correspond( Content => 'this is correspond text' );

$txns->FromSQL('Type = "Correspond"');
is( $txns->Count, 1, 'Found a correspond txn' );
is( $txns->Next->id, $correspond_txn_id, 'Found the correspond txn' );

$txns->FromSQL('Content LIKE "this is comment text"');
is( $txns->Count, 0, 'No txns with comment text' );

$txns->FromSQL('Content LIKE "this is correspond text"');
is( $txns->Count, 1, 'Found a correspond txn' );
is( $txns->Next->id, $correspond_txn_id, 'Found the correspond txn' );

$txns->FromSQL('Created > "tomorrow"');
is( $txns->Count, 0, 'No txns with future created date' );

$txns->FromSQL('Created >= "yesterday"');
ok( $txns->Count, 'Found txns with past created date' );

$txns->FromSQL("id = $correspond_txn_id");
is( $txns->Count, 1, 'Found the txn with id limit' );

$txns->FromSQL("id > 10000");
is( $txns->Count, 0, 'No txns with big ids yet' );

diag 'Test TicketResolved date search';
{
    # Create tickets with different resolved dates
    my $ticket1 = RT::Ticket->new( RT->SystemUser );
    my ($id1) = $ticket1->Create(
        Queue   => 'General',
        Subject => 'Resolved yesterday',
        Status  => 'resolved',
    );
    ok( $id1, 'Created ticket 1' );

    my $ticket2 = RT::Ticket->new( RT->SystemUser );
    my ($id2) = $ticket2->Create(
        Queue   => 'General',
        Subject => 'Resolved 5 days ago',
        Status  => 'resolved',
    );
    ok( $id2, 'Created ticket 2' );

    my $ticket3 = RT::Ticket->new( RT->SystemUser );
    my ($id3) = $ticket3->Create(
        Queue   => 'General',
        Subject => 'Resolved 10 days ago',
        Status  => 'resolved',
    );
    ok( $id3, 'Created ticket 3' );

    # Set different resolved dates using _Set to bypass normal date handling
    # Set to noon on each day to ensure they have a time component
    my $yesterday = RT::Date->new( RT->SystemUser );
    $yesterday->SetToNow;
    $yesterday->AddDays(-1);
    $yesterday->SetToMidnight( Timezone => 'UTC' );
    $yesterday->AddSeconds( 12 * 60 * 60 );  # noon

    my $five_days_ago = RT::Date->new( RT->SystemUser );
    $five_days_ago->SetToNow;
    $five_days_ago->AddDays(-5);
    $five_days_ago->SetToMidnight( Timezone => 'UTC' );
    $five_days_ago->AddSeconds( 12 * 60 * 60 );  # noon

    my $ten_days_ago = RT::Date->new( RT->SystemUser );
    $ten_days_ago->SetToNow;
    $ten_days_ago->AddDays(-10);
    $ten_days_ago->SetToMidnight( Timezone => 'UTC' );
    $ten_days_ago->AddSeconds( 12 * 60 * 60 );  # noon

    # Update resolved dates directly
    $ticket1->_Set( Field => 'Resolved', Value => $yesterday->ISO );
    $ticket2->_Set( Field => 'Resolved', Value => $five_days_ago->ISO );
    $ticket3->_Set( Field => 'Resolved', Value => $ten_days_ago->ISO );

    # Test searching with just a date (no time) using = operator
    my $yesterday_date = $yesterday->Date;  # Just YYYY-MM-DD
    $txns = RT::Transactions->new( RT->SystemUser );
    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id1 AND TicketResolved = '$yesterday_date'});
    is( $txns->Count, 1, "TicketResolved = '$yesterday_date' (date only) finds ticket resolved on that day" );

    # Also test with 5 days ago date
    my $five_days_date = $five_days_ago->Date;
    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id2 AND TicketResolved = '$five_days_date'});
    is( $txns->Count, 1, "TicketResolved = '$five_days_date' (date only) finds ticket resolved on that day" );

    # Test searching with full datetime using = operator
    my $yesterday_datetime = $yesterday->ISO;  # YYYY-MM-DD HH:MM:SS
    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id1 AND TicketResolved = '$yesterday_datetime'});
    is( $txns->Count, 1, "TicketResolved = '$yesterday_datetime' (datetime) finds ticket with exact match" );

    my $five_days_datetime = $five_days_ago->ISO;
    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id2 AND TicketResolved = '$five_days_datetime'});
    is( $txns->Count, 1, "TicketResolved = '$five_days_datetime' (datetime) finds ticket with exact match" );

    # Test that > and < operators still work with dates
    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id1 AND TicketResolved > '$five_days_date'});
    is( $txns->Count, 1, "TicketResolved > '$five_days_date' finds ticket resolved after that date" );

    $txns->FromSQL(qq{ObjectType = 'RT::Ticket' AND Type = 'Create' AND TicketId = $id3 AND TicketResolved < '$five_days_date'});
    is( $txns->Count, 1, "TicketResolved < '$five_days_date' finds ticket resolved before that date" );
}

diag 'Test HTML::Mason::Commands::PreprocessTransactionSearchQuery';

my %processed = (
    q{Type = 'Set'}                        => q{TicketType = 'ticket' AND ObjectType = 'RT::Ticket' AND Type = 'Set'},
    q{Type = 'Set' OR Type = 'Correspond'} =>
        q{TicketType = 'ticket' AND ObjectType = 'RT::Ticket' AND ( Type = 'Set' OR Type = 'Correspond' )},
    q{( Type = 'Set' ) OR ( Type = 'Correspond' )} =>
        q{TicketType = 'ticket' AND ObjectType = 'RT::Ticket' AND ( ( Type = 'Set' ) OR ( Type = 'Correspond' ) )},
    q{Type = 'Set' AND Field = 'Status'} =>
        q{TicketType = 'ticket' AND ObjectType = 'RT::Ticket' AND Type = 'Set' AND Field = 'Status'},
    q{( Type = 'Set' AND Field = 'Status' ) OR ( Type = 'Correspond' )} =>
        q{TicketType = 'ticket' AND ObjectType = 'RT::Ticket' AND ( ( Type = 'Set' AND Field = 'Status' ) OR ( Type = 'Correspond' ) )},
);

local $HTML::Mason::Commands::session{CurrentUser} = RT->SystemUser;
for my $query ( sort keys %processed ) {
    is( HTML::Mason::Commands::PreprocessTransactionSearchQuery( Query => $query ),
        $processed{$query}, "Processed query: $query" );
}

done_testing;
