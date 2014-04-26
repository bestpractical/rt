
use strict;
use warnings;

use RT;
use RT::Test tests => 17;

my ($id, $msg);
my $RecordTransaction;
my $UpdateLastUpdated;


use_ok('RT::Action::LinearEscalate');

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

# rt-cron-tool uses Gecos name to get rt user, so we'd better create one
my $gecos = RT::Test->load_or_create_user(
    Name => 'gecos',
    Password => 'password',
    Gecos => (getpwuid($<))[0],
);
ok $gecos && $gecos->id, 'loaded or created gecos user';

# get rid of all right permissions
$gecos->PrincipalObj->GrantRight( Right => 'SuperUser' );


my $user = RT::Test->load_or_create_user(
    Name => 'user', Password => 'password',
);
ok $user && $user->id, 'loaded or created user';

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );
my $current_user = RT::CurrentUser->new(RT->SystemUser);
($id, $msg) = $current_user->Load($user->id);
ok( $id, "Got current user? $msg" );

#defaults
$RecordTransaction = 0;
$UpdateLastUpdated = 1;
my $ticket2 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket2);
ok( $ticket2->LastUpdatedBy != $user->id, "Set LastUpdated" );
ok( $ticket2->Transactions->Last->Type =~ /Create/i, "Did not record a transaction" );

$RecordTransaction = 1;
$UpdateLastUpdated = 1;
my $ticket1 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket1);
ok( $ticket1->LastUpdatedBy != $user->id, "Set LastUpdated" );
ok( $ticket1->Transactions->Last->Type !~ /Create/i, "Recorded a transaction" );

$RecordTransaction = 0;
$UpdateLastUpdated = 0;
my $ticket3 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket3);
ok( $ticket3->LastUpdatedBy == $user->id, "Did not set LastUpdated" );
ok( $ticket3->Transactions->Last->Type =~ /Create/i, "Did not record a transaction" );

sub create_ticket_as_ok {
    my $user = shift;

    my $created = RT::Date->new(RT->SystemUser);
    $created->Unix(time() - ( 7 * 24 * 60**2 ));
    my $due = RT::Date->new(RT->SystemUser);
    $due->Unix(time() + ( 7 * 24 * 60**2 ));

    my $ticket = RT::Ticket->new($user);
    ($id, $msg) = $ticket->Create( Queue => $q->id,
                                   Subject => "Escalation test",
                                   Priority => 0,
                                   InitialPriority => 0,
                                   FinalPriority => 50,
                                 );
    ok($id, "Created ticket? ".$id);
    $ticket->__Set( Field => 'Created',
                    Value => $created->ISO,
                  );
    $ticket->__Set( Field => 'Due',
                    Value => $due->ISO,
                  );

    return $ticket;
}

sub escalate_ticket_ok {
    my $ticket = shift;
    my $id = $ticket->id;
    print "$RT::BinPath/rt-crontool --search RT::Search::FromSQL --search-arg \"id = @{[$id]}\" --action RT::Action::LinearEscalate --action-arg \"RecordTransaction:$RecordTransaction; UpdateLastUpdated:$UpdateLastUpdated\"\n";
    print STDERR `$RT::BinPath/rt-crontool --search RT::Search::FromSQL --search-arg "id = @{[$id]}" --action RT::Action::LinearEscalate --action-arg "RecordTransaction:$RecordTransaction; UpdateLastUpdated:$UpdateLastUpdated"`;

    $ticket->Load($id);     # reload, because otherwise we get the cached value
    ok( $ticket->Priority != 0, "Escalated ticket" );
}
