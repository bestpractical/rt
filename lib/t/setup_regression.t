#!/usr/bin/perl

use Test::More qw(no_plan);

use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");

# Create a new queue
use_ok(RT::Queue);
my $q = RT::Queue->new($RT::SystemUser);

$q->Load('regression');
if ($q->id != 0) {
        die "Regression tests not starting with a clean DB. Bailing";
}

my ($id, $msg) = $q->Create( Name => 'Regression',
            Description => 'A regression test queue',
            CorrespondAddress => 'correspond@a',
            CommentAddress => 'comment@a');

isnt($id, 0, "Queue was created sucessfully - $msg");

my $q2 = RT::Queue->new($RT::SystemUser);

ok($q2->Load($id));
is($q2->id, $id, "Sucessfully loaded the queue again");
is($q2->Name, 'Regression');
is($q2->Description, 'A regression test queue');
is($q2->CorrespondAddress, 'correspond@a');
is($q2->CommentAddress, 'comment@a');


