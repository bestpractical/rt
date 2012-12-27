
use warnings;
use strict;
use Data::Dumper;

use RT::Test nodata => 1, tests => 13;
use_ok('RT');
use_ok('RT::Transactions');


my $q = RT::Queue->new(RT->SystemUser);
my ($id,$msg) = $q->Create( Name => 'TxnCFTest'.$$);
ok($id,$msg);

my $cf = RT::CustomField->new(RT->SystemUser);
($id,$msg) = $cf->Create(Name => 'Txnfreeform-'.$$, Type => 'Freeform', MaxValues => '0', LookupType => RT::Transaction->CustomFieldLookupType );

ok($id,$msg);

($id,$msg) = $cf->AddToObject($q);

ok($id,$msg);


my $ticket = RT::Ticket->new(RT->SystemUser);

my $transid;
($id,$transid, $msg) = $ticket->Create(Queue => $q->id,
                Subject => 'TxnCF test',
            );
ok($id,$msg);

my $trans = RT::Transaction->new(RT->SystemUser);
$trans->Load($transid);

is($trans->ObjectId,$id);
is ($trans->ObjectType, 'RT::Ticket');
is ($trans->Type, 'Create');
my $txncfs = $trans->CustomFields;
is ($txncfs->Count, 1, "We have one custom field");
my $txn_cf = $txncfs->First;
is ($txn_cf->id, $cf->id, "It's the right custom field");
my $values = $trans->CustomFieldValues($txn_cf->id);
is ($values->Count, 0, "It has no values");

$trans->UpdateCustomFields( 'CustomField-'.$cf->id => 'Test');
$values = $trans->CustomFieldValues($txn_cf->id);
is ($values->Count, 1, "it has a value");

# TODO ok(0, "Should updating custom field values remove old values?");
