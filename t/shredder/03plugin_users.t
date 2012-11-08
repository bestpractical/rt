
use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 21 + 1; # plus one for warnings check
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}


my @ARGS = sort qw(limit status name member_of email replace_relations no_tickets);

use_ok('RT::Shredder::Plugin::Users');
{
    my $plugin = RT::Shredder::Plugin::Users->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Users');

    is(lc $plugin->Type, 'search', 'correct type');

    my @args = sort $plugin->SupportArgs;
    cmp_deeply(\@args, \@ARGS, "support all args");


    my ($status, $msg) = $plugin->TestArgs( name => 'r??t*' );
    ok($status, "arg name = 'r??t*'") or diag("error: $msg");

    for (qw(any disabled enabled)) {
        my ($status, $msg) = $plugin->TestArgs( status => $_ );
        ok($status, "arg status = '$_'") or diag("error: $msg");
    }
    ($status, $msg) = $plugin->TestArgs( status => '!@#' );
    ok(!$status, "bad 'status' arg value");
}

init_db();

RT::Test->set_rights(
    { Principal => 'Everyone', Right => [qw(CreateTicket)] },
);

create_savepoint('clean');

{ # Create two users and a ticket. Shred second user and replace relations with first user
    my ($uidA, $uidB, $msg);
    my $userA = RT::User->new( RT->SystemUser );
    ($uidA, $msg) = $userA->Create( Name => 'userA', Privileged => 1, Disabled => 0 );
    ok( $uidA, "created user A" ) or diag "error: $msg";

    my $userB = RT::User->new( RT->SystemUser );
    ($uidB, $msg) = $userB->Create( Name => 'userB', Privileged => 1, Disabled => 0 );
    ok( $uidB, "created user B" ) or diag "error: $msg";

    my ($tid, $trid);
    my $ticket = RT::Ticket->new( RT::CurrentUser->new($userB) );
    ($tid, $trid, $msg) = $ticket->Create( Subject => 'UserB Ticket', Queue => 1 );
    ok( $tid, "created new ticket") or diag "error: $msg";

    my $transaction = RT::Transaction->new( RT->SystemUser );
    $transaction->Load($trid);
    is ( $transaction->Creator, $uidB, "ticket creator is user B" );

    my $plugin = RT::Shredder::Plugin::Users->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Users');

    my $status;
    ($status, $msg) = $plugin->TestArgs( status => 'any', name => 'userB', replace_relations => $uidA );
    ok($status, "plugin arguments are ok") or diag "error: $msg";

    my @objs;
    ($status, @objs) = $plugin->Run;
    ok($status, "executed plugin successfully") or diag "error: @objs";
    @objs = RT::Shredder->CastObjectsToRecords( Objects => \@objs );
    is(scalar @objs, 1, "one object in the result set");

    my $shredder = shredder_new();

    ($status, $msg) = $plugin->SetResolvers( Shredder => $shredder );
    ok($status, "set conflicts resolver") or diag "error: $msg";

    $shredder->PutObjects( Objects => \@objs );
    $shredder->WipeoutAll;

    $ticket->Load( $tid );
    is($ticket->id, $tid, 'loaded ticket');

    $transaction->Load($trid);
    is ( $transaction->Creator, $uidA, "ticket creator is now user A" );

    $shredder->Wipeout( Object => $ticket );
    $shredder->Wipeout( Object => $userA );
}
cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
