use strict;
use warnings;

use RT::Test tests => undef;
use RT::Test::Email;
use Test::Warn;

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name         => 'root',
    EmailAddress => 'root@localhost',
);
ok $user && $user->id, 'loaded or created root user';

my $test_user = RT::Test->load_or_create_user(
    Name         => 'test',
    EmailAddress => 'test@localhost',
);
ok $test_user && $test_user->id, 'loaded or created test user';

my $nobody_user = RT::Test->load_or_create_user(
    Name         => 'nobody',
    EmailAddress => 'nobody@localhost',
);
ok $nobody_user && $nobody_user->id, 'loaded or created test user';


diag "Test creation of emails with a squelched requestor";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => [ 'root@localhost', 'test@localhost', 'nobody@localhost' ],
            SquelchMailTo => [ 'test@localhost' ],
        );
        ok $status, "created ticket";
    } { To => 'nobody@localhost, root@localhost' };

    RT->Config->Set( NotifyActor => 1 );
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'nobody@localhost, root@localhost' };

    RT->Config->Set( NotifyActor => 0 );
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'nobody@localhost' };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            CcMessageTo => 'root@localhost',
        );
        ok $status, "replied to a ticket";
    } { Cc => 'root@localhost'},{ To => 'nobody@localhost' };
} [];

diag "Reply to ticket with multiple requestors squelched";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => [ 'root@localhost', 'test@localhost', 'nobody@localhost' ],
            SquelchMailTo => [ 'root@localhost', 'nobody@localhost' ]
        );
        ok $status, "created ticket";
    } { To => 'test@localhost' };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'test@localhost' };

    $ticket->SquelchMailTo('test@localhost');
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            CcMessageTo => 'test@localhost',
        );
        ok $status, "replied to a ticket";
    } { Cc => 'test@localhost' };
}[];

done_testing;
