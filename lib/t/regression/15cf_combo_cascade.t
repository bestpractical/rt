#!/usr/bin/perl
use warnings;
use strict;
use Test::More qw/no_plan/;

use RT;
RT::LoadConfig();
RT::Init();

sub fail_ok {
    my ($cond, $msg) = @_;
    ok(!$cond, "This should fail: $msg");
}

sub new (*) {
    my $class = shift;
    return $class->new($RT::SystemUser);
}

my $q = new(RT::Queue);
ok($q->Create(Name => "CF-Pattern-".$$));

my $cf = new(RT::CustomField);
my @cf_args = (Name => $q->Name, Type => 'Combobox', Queue => $q->id);

ok($cf->Create(@cf_args));

# Set some CFVs with Category markers

my $t = new(RT::Ticket);
my ($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Test');
ok($id,$msg);

sub cnt { $cf->Values->Count };
sub add { $cf->AddValue(Field => $cf->id, Value => $_[0], Category => $_[1]) };

ok(add('value1', '1. Category A'));
is(cnt(), 1, "Value filled");
ok(add('value2'));
is(cnt(), 2, "Value filled");
ok(add('value3', '1.1. A-sub one'));
is(cnt(), 3, "Value filled");
ok(add('value4', '1.2. A-sub two'));
is(cnt(), 4, "Value filled");
ok(add('value5', ''));
is(cnt(), 5, "Value filled");

is($cf->Values->First->Category('1. Category A'), '1. Category A');

1;
