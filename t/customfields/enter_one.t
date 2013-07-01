use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;

my $q = RT::Test->load_or_create_queue(Name => 'General');
ok $q && $q->id, "loaded or created queue 'General'";

my $cf = RT::CustomField->new(RT->SystemUser);
my ($id,$msg) = $cf->Create(Name => 'Enter-One', Type => 'Freeform', MaxValues => '1', Queue => $q->id);
ok $id, $msg;

my $t = RT::Ticket->new(RT->SystemUser);
($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Enter-One Test');
ok $id, $msg;

$t->AddCustomFieldValue(Field => $cf->id, Value => 'LOWER');
is $t->FirstCustomFieldValue($cf->id), "LOWER", "CF value is 'LOWER'";

$t->AddCustomFieldValue(Field => $cf->id, Value => 'lower');
is $t->FirstCustomFieldValue($cf->id), "lower", "CF value changed from 'LOWER' to 'lower'";

done_testing();
