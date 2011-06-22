use RT::Test nodata => 1, tests => 9;

use strict;
use warnings;

my $queue = RT::Test->load_or_create_queue( Name => 'A' );
ok $queue && $queue->id, 'loaded or created queue_a';
my $qid = $queue->id;

my $user = RT::Test->load_or_create_user(
    Name => 'user',
    Password => 'password',
    EmailAddress => 'test@example.com',
);
ok $user && $user->id, 'loaded or created user';

{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc',       Right => [qw(ShowTicket)] },
    );
    my ($t) = RT::Test->create_tickets(
        { Queue => $queue->id },
        { },
    );
    my $rights = $user->PrincipalObj->HasRights( Object => $t );
    is_deeply( $rights, { SeeQueue => 1 }, 'got it' );

    ($t) = RT::Test->create_tickets(
        { Queue => $queue->id },
        { Cc => $user->EmailAddress },
    );
    ok($t->Cc->HasMember( $user->id ), 'user is cc');
    $rights = $user->PrincipalObj->HasRights( Object => $t );
    is_deeply( $rights, { SeeQueue => 1, ShowTicket => 1 }, 'got it' )
}

sub cleanup {
    RT::Test->delete_tickets( "Queue = $qid" );
    RT::Test->delete_queue_watchers( $queue );
}; 

