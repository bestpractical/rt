#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 13;

use RT;
RT::LoadConfig();
RT::Init();

sub fails { ok(!$_[0], "This should fail: $_[1]") }
sub works { ok($_[0], $_[1] || 'This works') }

sub new (*) {
    my $class = shift;
    return $class->new($RT::SystemUser);
}

my $q = new(RT::Queue);
works($q->Create(Name => "CF-Pattern-".$$));

my $cf = new(RT::CustomField);
my @cf_args = (Name => $q->Name, Type => 'Freeform', Queue => $q->id);

fails($cf->Create(@cf_args, Pattern => ')))bad!regex((('));
works($cf->Create(@cf_args, Pattern => 'good regex'));

my $t = new(RT::Ticket);
my ($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Test');
works($id,$msg);

# OK, I'm thoroughly brain washed by HOP at this point now...
sub cnt { $t->CustomFieldValues($cf->id)->Count };
sub add { $t->AddCustomFieldValue(Field => $cf->id, Value => $_[0]) };

is(cnt(), 0, "No values yet");
fails(add('not going to match'));
is(cnt(), 0, "No values yet");
works(add('here is a good regex'));
is(cnt(), 1, "Value filled");

fails($cf->SetPattern('(?{ "insert evil code here" })'));
works($cf->SetPattern('(?!)')); # reject everything
fails(add(''));
fails(add('...'));

1;
