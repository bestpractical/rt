use strict;
use warnings;
use RT::Test tests => 40;

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

ok(
    RT::Test->add_rights(
        {
            Principal => 'Owner',
            Right     => [qw/ModifyTicket/],
        },
    ),
    'add basic rights for owner'
);

my $ticket = RT::Test->create_ticket(
    Subject => 'test reminder permission',
    Queue   => 'General',
);

ok( $ticket->id, 'created a ticket' );

my ( $baseurl, $m ) = RT::Test->started_ok;
$m->login;

my ( $root_reminder_id, $user_a_reminder_id );
diag "create two reminders, with owner root and user_a, respectively";
{
    $m->goto_ticket( $ticket->id );
    $m->text_contains( 'New reminder:', 'can create a new reminder' );
    $m->form_name('UpdateReminders');
    $m->field( 'NewReminder-Subject' => "root reminder" );
    $m->submit;
    $m->text_contains( "Reminder 'root reminder': Created",
        'created root reminder' );

    $m->form_name('UpdateReminders');
    $m->field( 'NewReminder-Subject' => "user_a reminder", );
    $m->field( 'NewReminder-Owner'   => $user_a->id, );
    $m->submit;
    $m->text_contains( "Reminder 'user_a reminder': Created",
        'created user_a reminder' );

    my $reminders = RT::Reminders->new($user_a);
    $reminders->Ticket( $ticket->id );
    my $col = $reminders->Collection;
    while ( my $c = $col->Next ) {
        if ( $c->Subject eq 'root reminder' ) {
            $root_reminder_id = $c->id;
        }
        elsif ( $c->Subject eq 'user_a reminder' ) {
            $user_a_reminder_id = $c->id;
        }
    }
}

diag "check root_a can update user_a reminder but not root reminder";
my $m_a = RT::Test::Web->new;
{
    ok( $m_a->login( user_a => 'password' ), 'logged in as user_a' );
    $m_a->goto_ticket( $ticket->id );
    $m_a->content_lacks( 'New reminder:', 'can not create a new reminder' );
    $m_a->content_contains( 'root reminder',   'can see root reminder' );
    $m_a->content_contains( 'user_a reminder', 'can see user_a reminder' );
    $m_a->content_like(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is disabled"
    );

    $m_a->form_name('UpdateReminders');
    $m_a->tick( "Complete-Reminder-$user_a_reminder_id" => 1 );
    $m_a->submit;
    $m_a->text_contains(
        "Reminder 'user_a reminder': Status changed from 'open' to 'resolved'",
        'complete user_a reminder' );

    $m_a->follow_link_ok( { id => 'page-reminders' } );
    $m_a->title_is("Reminders for ticket #" . $ticket->id . ": " . $ticket->Subject);
    $m_a->content_contains( 'root reminder',   'can see root reminder' );
    $m_a->content_contains( 'user_a reminder', 'can see user_a reminder' );
    $m_a->content_lacks( 'New reminder:', 'can not create a new reminder' );
    $m_a->content_like(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is disabled"
    );

    $m_a->form_name('UpdateReminders');
    $m_a->untick( "Complete-Reminder-$user_a_reminder_id", 1 );
    $m_a->submit;
    $m_a->text_contains(
        "Reminder 'user_a reminder': Status changed from 'resolved' to 'open'",
        'reopen user_a reminder'
    );

}

diag "set ticket owner to user_a to let user_a grant modify ticket right";
{
    $ticket->SetOwner( $user_a->id );

    $m_a->goto_ticket( $ticket->id );
    $m_a->content_contains( 'New reminder:', 'can create a new reminder' );
    $m_a->content_like(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is still disabled"
    );
    $m_a->form_name('UpdateReminders');
    $m_a->field( 'NewReminder-Subject' => "user_a from display reminder" );
    $m_a->submit;
    $m_a->text_contains( "Reminder 'user_a from display reminder': Created",
        'created user_a from display reminder' );

    $m_a->follow_link_ok( { id => 'page-reminders' } );
    $m_a->title_is("Reminders for ticket #" . $ticket->id . ": " . $ticket->Subject);
    $m_a->content_contains( 'New reminder:', 'can create a new reminder' );
    $m_a->content_like(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is still disabled"
    );
    $m_a->form_name('UpdateReminders');
    $m_a->field( 'NewReminder-Subject' => "user_a from reminders reminder" );
    $m_a->submit;
    $m_a->text_contains( "Reminder 'user_a from reminders reminder': Created",
        'created user_a from reminders reminder' );
}

diag "grant user_a with ModifyTicket globally";
{
    ok(
        RT::Test->add_rights(
            {
                Principal => $user_a,
                Right     => [qw/ModifyTicket/],
            },
        ),
        'add ModifyTicket rights to user_a'
    );

    $m_a->goto_ticket( $ticket->id );
    $m_a->content_unlike(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is enabled"
    );
    $m_a->form_name('UpdateReminders');
    $m_a->tick( "Complete-Reminder-$root_reminder_id" => 1 );
    $m_a->submit;
    $m_a->text_contains(
        "Reminder 'root reminder': Status changed from 'open' to 'resolved'",
        'complete root reminder' );

    $m_a->follow_link_ok( { id => 'page-reminders' } );
    $m_a->content_unlike(
qr!<input[^/]+name="Complete-Reminder-$root_reminder_id"[^/]+disabled="disabled"!,
        "root reminder checkbox is enabled"
    );
    $m_a->form_name('UpdateReminders');
    $m_a->untick( "Complete-Reminder-$root_reminder_id" => 1 );
    $m_a->submit;
    $m_a->text_contains(
        "Reminder 'root reminder': Status changed from 'resolved' to 'open'",
        'reopen root reminder' );
}

