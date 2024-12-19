
use strict;
use warnings;
use RT;
use RT::Test tests => undef;

use_ok('RT::RightsInspector');
ok (my $cu = RT::CurrentUser->new('root'), 'Created root current user');

my $user = RT::Test->load_or_create_user(
    Name => 'user', Password => 'password',
);
ok $user && $user->id, 'loaded or created user';

my $queue = RT::Test->load_or_create_queue( Name => 'TestingQueue' );
ok $queue && $queue->id, 'loaded or created queue';
my $qname = $queue->Name;

diag 'Global Rights Inspector tests';
{
    my %args = (
        continueAfter => 0,
        object        => "",
        principal     => "user:root",
        right         => "SuperUser",
        user          => $cu,
    );

    my $results = RT::RightsInspector->Search(%args);

    ok( scalar @{$results->{results}}, 'Got a record' );
    is( $results->{results}->[0]->{right}, 'SuperUser', 'Found SuperUser right' );
    is( $results->{results}->[0]->{principal}{id}, $cu->Id, 'User is root' );
}

diag 'Ticket rights test';
{

    # Set up AdminCc rights
    my $group = $queue->RoleGroup( 'AdminCc' );
    ok( $group->Id, "load queue AdminCc role group" );
    my $ace = RT::ACE->new( RT->SystemUser );
    my ($ace_id, $msg) = $group->PrincipalObj->GrantRight(
        Right => 'ModifyTicket', Object => $queue
    );
    ok( $ace_id, "Granted queue AdminCc role group with ModifyTicket right: $msg" );
    ok( $group->PrincipalObj->HasRight( Right => 'ModifyTicket', Object => $queue ),
        "role group can modify ticket"
    );

    my %args = (
        continueAfter => 0,
        object        => $qname,
        principal     => "",
        right         => "",
        user          => $cu,
    );

    my $results = RT::RightsInspector->Search(%args);

    ok( scalar @{$results->{results}}, 'Got a record' );
    is( $results->{results}->[0]->{right}, 'ModifyTicket', 'Found ModifyTicket right' );
    is( $results->{results}->[0]->{object}{id}, $queue->Id, "Object is $qname" );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($ticket_id) = $ticket->Create( Queue => $queue->id, Subject => 'test');
    ok( $ticket_id, 'new ticket created' );
    is( $ticket->Owner, RT->Nobody->Id, 'owner of the new ticket is nobody' );

    my $status;
    ($status, $msg) = $ticket->AddWatcher(
        Type => 'AdminCc', PrincipalId => $user->PrincipalId
    );
    ok( $status, "Successfully added user as AdminCc");
    ok( $user->HasRight( Right => 'ModifyTicket', Object => $ticket ),
        "user is AdminCc and can modify ticket"
    );

    %args = (
        continueAfter => 0,
        object        => "",
        principal     => 'user:' . $user->Id,
        right         => "ModifyTicket",
        user          => $cu,
    );

    $results = RT::RightsInspector->Search(%args);

    ok( scalar @{$results->{results}}, 'Got a record' );
    is( $results->{results}->[0]->{right}, 'ModifyTicket', 'Found ModifyTicket right' );
    is( $results->{results}->[0]->{object}{id}, $queue->Id, "Object is $qname" );
    is( $results->{results}->[0]->{principal}{label}, 'AdminCc', 'Right label is AdminCc' );
    is( $results->{results}->[0]->{principal}{primary_record}{id}, $user->Id, 'primary_record is test user' );
}

done_testing;
