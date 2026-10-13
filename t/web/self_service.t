use strict;
use warnings;

use RT::Test
  tests  => undef,
  config => 'Set( $ShowUnreadMessageNotifications, 1 );'
;

my ($url, $m) = RT::Test->started_ok;

my $user_a = RT::Test->load_or_create_user(
    Name         => 'user_a',
    Password     => 'password',
    EmailAddress => 'user_a@example.com',
    Privileged   => 0,
);
ok( $user_a && $user_a->id, 'loaded or created user' );
ok( ! $user_a->Privileged, 'user is not privileged' );

# Load Cc group
my $Cc = RT::System->RoleGroup( 'Cc' );
ok($Cc->id);
RT::Test->add_rights( { Principal => $Cc, Right => ['ShowTicket'] } );

my ($ticket) = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test subject',
    Cc      => 'user_a@example.com',
);

my @results = $ticket->Correspond( Content => 'sample correspondence' );

ok( $m->login('user_a' => 'password'), 'unprivileged user logged in' );

$m->get_ok( '/SelfService/Display.html?id=' . $ticket->id,
    'got selfservice display page' );

my $title = '#' . $ticket->id . ': test subject';
$m->title_is( $title );
$m->content_contains( "<h1>$title</h1>", "contains <h1>$title</h1>" );

# $ShowUnreadMessageNotifications tests:
$m->content_contains( "There are unread messages on this ticket." );

# mark the message as read
$m->follow_link_ok(
    { text => 'Mark as Seen' },
    'followed mark as seen link'
);

$m->content_contains( "<h1>$title</h1>", "contains <h1>$title</h1>" );
$m->content_lacks( "There are unread messages on this ticket." );

$m->follow_link_ok( { url_regex => qr{^/SelfService/Transaction/Display.html}, n => 2 }, 'Followed transaction link' );

$m->text_contains('sample correspondence');

ok( !$m->find_link( url_regex => qr{^/Ticket/} ),     'No privileged ticket links found' );
ok( !$m->find_link( url_regex => qr{^Update.html} ),  'No self service update links found' );


$m->follow_link_ok( { url_regex => qr{^/SelfService/Attachment/}, }, 'Followed self service attachment link' );
$m->text_contains('sample correspondence');
$m->back;

RT::Test->add_rights( { Principal => $Cc, Right => ['ReplyToTicket'] } );
$m->reload;
$m->follow_link_ok( { url_regex => qr{^/SelfService/Update.html}, }, 'Followed self service ticket link' );
$m->submit_form_ok(
    {
        form_name   => 'TicketUpdate',
        with_fields => { UpdateContent => 'Test correspondence from self service' },
        button => 'SubmitTicket',
    },
    'Submitted self service update form'
);
$m->text_contains('Correspondence added');
$m->text_contains('Test correspondence from self service');

diag 'Custom field changed by staff while the reply form is open';
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'Customer Priority',
        Queue => 'General',
        Type  => 'SelectSingle',
    );
    for my $value (qw/P1 P2 P3/) {
        my ( $ok, $msg ) = $cf->AddValue( Name => $value );
        ok( $ok, "Added Customer Priority value $value" ) or diag $msg;
    }
    RT::Test->add_rights( { Principal => $Cc, Right => [ 'SeeCustomField', 'ModifyCustomField' ] } );

    my ( $ok, $msg ) = $ticket->AddCustomFieldValue( Field => $cf->Id, Value => 'P3' );
    ok( $ok, 'Set Customer Priority to P3' ) or diag $msg;

    my $input = 'Object-RT::Ticket-' . $ticket->Id . '-CustomField-' . $cf->Id . '-Values';
    my $priority_is = sub {
        my ( $expected, $description ) = @_;
        my $current = RT::Ticket->new( RT->SystemUser );
        $current->Load( $ticket->Id );
        is( $current->FirstCustomFieldValue( $cf->Id ), $expected, $description );
    };

    $m->get_ok( '/SelfService/Update.html?id=' . $ticket->Id );
    is( $m->form_name('TicketUpdate')->value($input), 'P3', 'Reply form shows Customer Priority P3' );

    ( $ok, $msg ) = $ticket->AddCustomFieldValue( Field => $cf->Id, Value => 'P1' );
    ok( $ok, 'Staff changed Customer Priority to P1' ) or diag $msg;

    $m->submit_form_ok(
        {   form_name => 'TicketUpdate',
            fields    => { UpdateContent => 'Reply from a form opened before the change' },
            button    => 'SubmitTicket',
        },
        'Submitted the reply without touching Customer Priority'
    );
    $priority_is->( 'P1', 'Reply keeps the Customer Priority set by staff' );

    $m->get_ok( '/SelfService/Update.html?id=' . $ticket->Id );
    $m->submit_form_ok(
        {   form_name => 'TicketUpdate',
            fields    => { UpdateContent => 'Reply raising the priority', $input => 'P2' },
            button    => 'SubmitTicket',
        },
        'Submitted the reply changing Customer Priority'
    );
    $priority_is->( 'P2', 'Reply saves a Customer Priority the user changed' );
}


diag 'Test $SelfServiceUserPrefs config';
{
  # Verify the $SelfServiceUserPrefs config option renders the correct display at
  # /SelfService/Prefs.html for each of the available options

  is( RT->Config->Get( 'SelfServiceUserPrefs' ), 'edit-prefs', '$SelfServiceUserPrefs is set to "edit-prefs" by default' );

  for my $config ( 'edit-prefs', 'view-info', 'edit-prefs-view-info', 'full-edit' ) {
    RT::Test->stop_server;
    RT->Config->Set( SelfServiceUserPrefs => $config );
    ( $url, $m ) = RT::Test->started_ok;
    ok( $m->login('user_a' => 'password'), 'unprivileged user logged in' );
    $m->get_ok( '/SelfService/Prefs.html');

    if ( $config eq 'edit-prefs' ) {
      $m->content_lacks( 'Nickname', "'Edit-Prefs' option does not contain full user info" );
      $m->content_contains( '<input type="password" class="form-control" name="CurrentPass"', "'Edit-Prefs' option contains default user info" );
    } elsif ( $config eq 'view-info' ) {
      $m->content_lacks( 'name="NickName" value=""', "'View-Info' option contains no input fields for full user info" );
      $m->content_contains( "Nickname:", "'View-Info' option contains full user info" );
    } elsif ( $config eq 'edit-prefs-view-info' ) {
      $m->content_contains( '<input type="password" class="form-control" name="CurrentPass"', "'Edit-Prefs-View-Info' option contains default user info" );
      $m->content_contains( 'Nickname:', "'Edit-Prefs-View-Info' option contains full user info" );
      $m->content_lacks( 'name="NickName" value=""', "'Edit-Prefs-View-Info' option contains no input fields for full user info" );
    } else {
      RT::Test->add_rights( { Principal => $user_a, Right => ['ModifySelf'] } );
      my $nickname = 'user_a_nickname';
      $m->submit_form_ok({
        form_name  => 'EditAboutMe',
        with_fields     => { NickName => $nickname,}
      }, 'Form submitted');
      $m->text_contains("NickName changed from (no value) to '$nickname'", "NickName updated");
    }
  }
}

# TODO need more SelfService tests

done_testing();
