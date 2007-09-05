#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 8;

use RT;
use RT::Test;



my $q = RT::Model::Queue->new($RT::SystemUser);
my ($id,$msg) =$q->create(Name => "CF-Single-".$$);
ok($id,$msg);

my $cf = RT::Model::CustomField->new($RT::SystemUser);
($id,$msg) = $cf->create(Name => 'Single-'.$$, Type => 'Select', MaxValues => '1', Queue => $q->id);
ok($id,$msg);


($id,$msg) =$cf->AddValue(Name => 'First');
ok($id,$msg);

($id,$msg) =$cf->AddValue(Name => 'Second');
ok($id,$msg);


my $t = RT::Model::Ticket->new($RT::SystemUser);
($id,undef,$msg) = $t->create(Queue => $q->id,
          Subject => 'CF Test');

ok($id,$msg);
is($t->CustomFieldValues($cf->id)->count, 0, "No values yet");
$t->AddCustomFieldValue(Field => $cf->id, value => 'First');
is($t->CustomFieldValues($cf->id)->count, 1, "One now");

$t->AddCustomFieldValue(Field => $cf->id, value => 'Second');
is($t->CustomFieldValues($cf->id)->count, 1, "Still one");

1;
