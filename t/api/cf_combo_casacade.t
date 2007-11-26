#!/usr/bin/perl
use warnings;
use strict;
use RT::Test; use Test::More tests => 13;



sub fails { ok(!$_[0], "This should fail: $_[1]") }
sub works { ok($_[0], $_[1] || 'This works') }

sub new (*) {
    my $class = shift;
    return $class->new(RT->system_user);
}

my $q = new(RT::Model::Queue);
works($q->create(Name => "CF-Pattern-".$$));

my $cf = new(RT::Model::CustomField);
my @cf_args = (Name => $q->Name, Type => 'Combobox', Queue => $q->id);

works($cf->create(@cf_args));

# Set some CFVs with Category markers

my $t = new(RT::Model::Ticket);
my ($id,undef,$msg) = $t->create(Queue => $q->id, Subject => 'CF Test');
works($id,$msg);

sub add_works {
    works(
        $cf->AddValue(Name => $_[0], Description => $_[0], Category => $_[1])
    );
};

add_works('value1', '1. Category A');
add_works('value2');
add_works('value3', '1.1. A-sub one');
add_works('value4', '1.2. A-sub two');
add_works('value5', '');

my $cfv = $cf->Values->first;
is ($cf->Values->count,5, "got 5 values");
is($cfv->Name, 'value1', "We got the first value");
is($cfv->Category, '1. Category A');
works($cfv->set_Category('1. Category AAA'));
is($cfv->Category, '1. Category AAA');

1;
