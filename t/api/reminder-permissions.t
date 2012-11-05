use strict;
use warnings;
use RT::Test tests => 9;

my $user_a = RT::Test->load_or_create_user(
    Name     => 'user_a',
    Password => 'password',
);

ok( $user_a && $user_a->id, 'created user_a' );
ok(
    RT::Test->add_rights(
        {
            Principal => $user_a,
            Right     => [qw/SeeQueue CreateTicket ShowTicket OwnTicket/]
        },
    ),
    'add basic rights for user_a'
);

my $ticket = RT::Test->create_ticket(
    Subject => 'test reminder permission',
    Queue   => 'General',
);
ok( $ticket->id, 'created a ticket' );
$ticket->CurrentUser($user_a);

my ( $status, $msg ) = $ticket->Reminders->Add(
    Subject => 'user a reminder',
    Owner   => $user_a->id,
);
ok( !$status, "couldn't create reminders without ModifyTicket: $msg" );

ok(
    RT::Test->add_rights(
        {
            Principal => $user_a,
            Right     => [qw/ModifyTicket/]
        },
    ),
    'add ModifyTicket right for user_a'
);

( $status, $msg ) = $ticket->Reminders->Add(
    Subject => 'user a reminder',
    Owner   => $user_a->id,
);
ok( $status, "created a reminder with ModifyTicket: $msg" );

