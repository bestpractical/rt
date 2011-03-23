use warnings;
use strict;

use RT;
use RT::Test nodata => 1, tests => 8;



my $q = RT::Queue->new(RT->SystemUser);
my ($id,$msg) =$q->Create(Name => "CF-Single-".$$);
ok($id,$msg);

my $cf = RT::CustomField->new(RT->SystemUser);
($id,$msg) = $cf->Create(Name => 'Single-'.$$, Type => 'Select', MaxValues => '1', Queue => $q->id);
ok($id,$msg);


($id,$msg) =$cf->AddValue(Name => 'First');
ok($id,$msg);

($id,$msg) =$cf->AddValue(Name => 'Second');
ok($id,$msg);


my $t = RT::Ticket->new(RT->SystemUser);
($id,undef,$msg) = $t->Create(Queue => $q->id,
          Subject => 'CF Test');

ok($id,$msg);
is($t->CustomFieldValues($cf->id)->Count, 0, "No values yet");
$t->AddCustomFieldValue(Field => $cf->id, Value => 'First');
is($t->CustomFieldValues($cf->id)->Count, 1, "One now");

$t->AddCustomFieldValue(Field => $cf->id, Value => 'Second');
is($t->CustomFieldValues($cf->id)->Count, 1, "Still one");

