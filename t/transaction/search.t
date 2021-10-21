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

done_testing;
