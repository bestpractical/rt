use warnings;
use strict;

use RT;
use RT::Test nodata => 1, tests => 17;

my $q = RT::Queue->new($RT::SystemUser);
works($q->Create(Name => "CF-Pattern-".$$));

my $cf = RT::CustomField->new($RT::SystemUser);
my @cf_args = (Name => $q->Name, Type => 'Freeform', Queue => $q->id, MaxValues => 1);

fails($cf->Create(@cf_args, Pattern => ')))bad!regex((('));
works($cf->Create(@cf_args, Pattern => 'good regex'));

my $t = RT::Ticket->new($RT::SystemUser);
my ($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Test');
works($id,$msg);

# OK, I'm thoroughly brain washed by HOP at this point now...
sub cnt { $t->CustomFieldValues($cf->id)->Count };
sub add { $t->AddCustomFieldValue(Field => $cf->id, Value => $_[0]) };
sub del { $t->DeleteCustomFieldValue(Field => $cf->id, Value => $_[0]) };

is(cnt(), 0, "No values yet");
fails(add('not going to match'));
is(cnt(), 0, "No values yet");
works(add('here is a good regex'));
is(cnt(), 1, "Value filled");
fails(del('here is a good regex'));
is(cnt(), 1, "Single CF - Value _not_ deleted");

$cf->SetMaxValues(0);   # Unlimited MaxValues

works(del('here is a good regex'));
is(cnt(), 0, "Multiple CF - Value deleted");

fails($cf->SetPattern('(?{ "insert evil code here" })'));
works($cf->SetPattern('(?!)')); # reject everything
fails(add(''));
fails(add('...'));

undef $t;
