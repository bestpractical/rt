#!/usr/bin/perl
use warnings;
use strict;
use RT::Test strict => 1; use Test::More tests => 10;



sub fails { ok(!$_[0], "This should fail: $_[1]") }
sub works { ok($_[0], $_[1] || 'This works') }

sub new {
    my $class = shift;
    return $class->new(current_user => RT->system_user);
}

my $q = new( 'RT::Model::Queue');
works($q->create(name => "CF-Pattern-".$$));

my $cf = new('RT::Model::CustomField');
my @cf_args = (name => $q->name, type => 'Combobox', queue => $q->id);

works($cf->create(@cf_args));

# Set some CFVs

my $t = new( 'RT::Model::Ticket');
my ($id,undef,$msg) = $t->create(queue => $q->id, subject => 'CF Test');
works($id,$msg);

sub add_works {
    works(
        $cf->add_value(name => $_[0], description => $_[0] )
    );
};

add_works('value1');
add_works('value2');
add_works('value3');
add_works('value4');
add_works('value5');

my $cfv = $cf->values->first;
is ($cf->values->count,5, "got 5 values");
is($cfv->name, 'value1', "We got the first value");

1;
