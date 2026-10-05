use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my $user = RT::Test->load_or_create_user(
    Name     => 'user',
    Password => 'password',
);

my $cf = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue->Name, Type => 'FreeformSingle' );
my $cf_form_id = 'Object-RT::Ticket--CustomField-'.$cf->Id.'-Value';
my $cf_test_value = "some string for test_cf $$";

my ( $baseurl, $m ) = RT::Test->started_ok;
ok(
    RT::Test->set_rights(
        { Principal => $user, Right => [qw(SeeQueue CreateTicket)] },
        { Principal => $user, Object => $queue, Right => [qw(SeeCustomField ModifyCustomField)] }
    ),
    'set rights'
);

ok $m->login( 'user', 'password' ), 'logged in as user';

diag "test ShowTicket right";
{

    $m->get_ok( '/Ticket/Create.html?Queue=' . $queue->id,
        'go to ticket create page' );
    my $form = $m->form_name('TicketCreate');
    $m->submit_form( fields => { Subject => 'ticket foo', $cf_form_id => $cf_test_value }, button => 'SubmitTicket' );

    my $ticket = RT::Test->last_ticket;
    ok( $ticket->id, 'ticket is created' );
    my $id = $ticket->id;

    $m->content_lacks( "Ticket $id created", 'created ticket' );
    $m->content_contains( "No permission to view newly created ticket #$id",
        'got no permission msg' );
    $m->warning_like( qr/No permission to view newly created ticket #$id/,
        'got no permission warning' );


    $m->goto_ticket($id, undef, HTTP::Status::HTTP_FORBIDDEN);
    is($m->status, HTTP::Status::HTTP_FORBIDDEN, 'No permission');
    $m->content_contains( "No permission to view ticket",
        'got no permission msg' );
    $m->warning_like( qr/No permission to view ticket/, 'got warning' );
    $m->title_is('RT Error');

    ok(
        RT::Test->add_rights(
            { Principal => $user, Right => [qw(ShowTicket)] },
        ),
        'add ShowTicket right'
    );

    $m->reload;

    $m->content_lacks( "No permission to view ticket", 'no error msg' );
    $m->title_is( "#$id: ticket foo", 'we can it' );
    $m->content_contains($cf_test_value, "Custom Field was submitted and saved");
}

diag "UsernameFormat controls user avatars";
{
    my $root = RT::User->new( RT->SystemUser );
    $root->Load('root');

    my $ticket = RT::Test->create_ticket(
        Queue     => $queue->id,
        Subject   => 'avatar test',
        Owner     => $root->id,
        Requestor => 'avatar-requestor@example.com',
    );
    my $requestor = $ticket->Requestors->UserMembersObj->First;
    my $unowned   = RT::Test->create_ticket( Queue => $queue->id, Subject => 'unowned avatar test' );
    ok( !$requestor->Privileged, 'requestor is unprivileged' );

    my $root_m = RT::Test::Web->new;
    ok $root_m->login, 'logged in as root';

    my $initials = $root->GetInitials;
    my $name     = RT::User->Format( User => $root, Format => 'concise' );
    my %expected = (
        'concise'                  => { owner => 1, requestor => 1, nobody => 1, menu => 1, menu_text => $initials },
        'concise-noavatar'         => { owner => 0, requestor => 0, nobody => 0, menu => 0, menu_text => $name },
        'concise-privilegedavatar' => { owner => 1, requestor => 0, nobody => 1, menu => 1, menu_text => $initials },
    );

    for my $format ( sort keys %expected ) {
        $root_m->get_ok( $baseurl . '/Prefs/Other.html' );
        $root_m->submit_form_ok(
            {   form_name => 'ModifyPreferences',
                fields    => { UsernameFormat => $format },
                button    => 'Update',
            },
            "set UsernameFormat to $format"
        );

        $root_m->goto_ticket( $ticket->id );
        my $people = $root_m->dom->at('.ticket-info-people');
        ok( $people, 'found people widget' );

        for my $who ( [ owner => $root ], [ requestor => $requestor ] ) {
            my ( $role, $user ) = @$who;
            my $span = $people->at( 'span.user[data-user-id="' . $user->id . '"]' );
            ok( $span, "found $role in people widget" );
            is( $span->find('span.rt-user-avatar')->size,
                $expected{$format}{$role}, "$format: $role avatar count" );
            my $name = RT::User->Format( User => $user, Format => 'concise' );
            like( $span->all_text, qr/\Q$name\E\s*$/, "$format: $role name is shown" );
        }

        my $menu_user = $root_m->dom->at('#li-preferences > a span.user');
        ok( $menu_user, 'found user menu entry' );
        is( $menu_user->find('span.rt-user-avatar')->size,
            $expected{$format}{menu}, "$format: user menu avatar count" );
        is( $menu_user->all_text =~ s/^\s+|\s+$//gr, $expected{$format}{menu_text}, "$format: user menu text" );

        $root_m->goto_ticket( $unowned->id );
        my $nobody = $root_m->dom->at( '.ticket-info-people span.user[data-user-id="' . RT->Nobody->id . '"]' );
        ok( $nobody, 'found Nobody as owner' );
        is( $nobody->find('span.rt-user-avatar')->size, $expected{$format}{nobody}, "$format: Nobody avatar count" );
    }

    diag "One-time Cc address with no RT user";

    $root_m->get_ok( $baseurl . '/Prefs/Other.html' );
    $root_m->submit_form_ok(
        {   form_name => 'ModifyPreferences',
            fields    => { UsernameFormat => 'concise-privilegedavatar' },
            button    => 'Update',
        },
        'set UsernameFormat to concise-privilegedavatar'
    );

    my ( $status, $mail_id ) = RT::Test->send_via_mailgate(<<'EOF2');
From: root@localhost
Cc: onetime-cc@example.com
Subject: one-time cc

one-time cc
EOF2
    is( $status >> 8, 0, 'created ticket via mailgate' );

    my $onetime = RT::User->new( RT->SystemUser );
    $onetime->LoadByEmail('onetime-cc@example.com');
    ok( !$onetime->id, 'one-time Cc address has no RT user' );

    $root_m->goto_ticket( $mail_id, 'Update' );
    my $label = $root_m->dom->at('label[for="UpdateCc-onetime-cc@example.com"] span.user');
    ok( $label, 'found one-time Cc suggestion' );
    is( $label->find('.rt-user-avatar')->size, 0, 'one-time Cc suggestion has no avatar' );
    like( $label->all_text, qr/^\s*onetime-cc\@example\.com\s*$/, 'one-time Cc suggestion shows the address' );
}

done_testing();
