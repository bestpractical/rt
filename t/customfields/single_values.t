use warnings;
use strict;

use RT;
use RT::Test tests => undef;



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

my $ok;
my $value = 'First';
($ok, $msg) = $t->AddCustomFieldValue(Field => $cf->id, Value => $value);
ok( $ok, $msg );
is($t->CustomFieldValues($cf->id)->Count, 1, "One now");
is($t->FirstCustomFieldValue($cf->id), $value, "Value is $value");

$value = 'Second';
($ok, $msg) = $t->AddCustomFieldValue(Field => $cf->id, Value => $value);
ok( $ok, $msg );
is($t->CustomFieldValues($cf->id)->Count, 1, "Still one value");
is($t->FirstCustomFieldValue($cf->id), $value, "Value is $value");

($ok, $msg) = $t->AddCustomFieldValue(Field => $cf->id, Value => 'Bogus');
ok( !$ok, 'Returned false with value not in values list' );
like( $msg, qr/Invalid value/, 'Message reports invalid value');
is($t->CustomFieldValues($cf->id)->Count, 1, "Still one");
is($t->FirstCustomFieldValue($cf->id), $value, "Value is still $value");

done_testing();
