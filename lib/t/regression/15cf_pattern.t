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
my @cf_args = (Name => $q->Name, Type => 'Freeform', Queue => $q->id);

fail_ok($cf->Create(@cf_args, Pattern => ')))bad!regex((('));
ok($cf->Create(@cf_args, Pattern => 'good regex'));

my $t = new(RT::Ticket);
my ($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Test');
ok($id,$msg);

# OK, I'm thoroughly brain washed by HOP at this point now...
sub cnt { $t->CustomFieldValues($cf->id)->Count };
sub add { $t->AddCustomFieldValue(Field => $cf->id, Value => $_[0]) };

is(cnt(), 0, "No values yet");
fail_ok(add('not going to match'));
is(cnt(), 0, "No values yet");
ok(add('here is a good regex'));
is(cnt(), 1, "Value filled");

fail_ok($cf->SetPattern('(?{ "insert evil code here" })'));
ok($cf->SetPattern('(?!)')); # reject everything
fail_ok(add(''));
fail_ok(add('...'));

1;
