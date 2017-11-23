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
ok $user && $user->id, 'loaded or created user';

diag "Reply to ticket with actor as one time cc";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => 'root@localhost',
        );
        ok $status, "created ticket";
    } { To => 'root@localhost' };

    RT->Config->Set( NotifyActor => 1 );
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'root@localhost' };

    RT->Config->Set( NotifyActor => 0 );
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            CcMessageTo => 'root@localhost',
        );
        ok $status, "replied to a ticket";
    } { Cc => 'root@localhost' };
} [];

diag "Reply to ticket with requestor squelched";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => 'test@localhost',
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

diag "Reply to ticket with multiple requestors squelched";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test squelch',
            Requestor => ['test@localhost','bob@localhost','fred@localhost' ],
        );
        ok $status, "created ticket";
    } { To => 'bob@localhost, fred@localhost, test@localhost' };

    mail_ok {
        my ($status,$msg) = $ticket->Correspond(
            Content => 'squelched email',
            SquelchMailTo => ['bob@localhost', 'fred@localhost'],
        );
        ok $status, "replied to a ticket";
    } { To => 'test@localhost' };

} [];

diag "Reply to ticket with requestor squelched";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => 'test@localhost',
        );
        ok $status, "created ticket";
    } { To => 'test@localhost' };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'test@localhost' };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            SquelchMailTo => ['test@localhost'],
        );
        ok $status, "replied to a ticket";
    };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    } { To => 'test@localhost' };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            CcMessageTo => 'test@localhost',
            SquelchMailTo => ['test@localhost'],
        );
        ok $status, "replied to a ticket";
    }  { Cc => 'test@localhost' };
} [];

diag "Requestor is an RT address";
warnings_are {
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => 'test',
            Requestor => 'rt-address@example.com',
        );
        ok $status, "created ticket";
    } { To => 'rt-address@example.com' };

    RT->Config->Set( RTAddressRegexp => qr/^rt-address\@example\.com$/i );
    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
        );
        ok $status, "replied to a ticket";
    };

    mail_ok {
        my ($status, $msg) = $ticket->Correspond(
            Content => 'test mail',
            CcMessageTo => 'rt-address@example.com',
        );
        ok $status, "replied to a ticket";
    };
} [];

done_testing;
