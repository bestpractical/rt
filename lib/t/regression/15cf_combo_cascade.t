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

sub add_ok {
    my ($id, $msg) = $cf->AddValue(Name => $_[0], Description => $_[0], Category => $_[1]);
    ok($id, $msg);
};

add_ok('value1', '1. Category A');
add_ok('value2');
add_ok('value3', '1.1. A-sub one');
add_ok('value4', '1.2. A-sub two');
add_ok('value5', '');

my $cfv = $cf->Values->First;
is($cfv->Category, '1. Category A');
ok($cfv->SetCategory('1. Category AAA'));
is($cfv->Category, '1. Category AAA');

1;
