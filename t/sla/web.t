use strict;
use warnings;

BEGIN {
    use Test::MockTime 'set_fixed_time';
    use constant TIME => 1442455200;
    set_fixed_time(TIME);

    use RT::Test
        tests => undef,
        config => "use Test::MockTime 'set_fixed_time'; set_fixed_time(". TIME . q!);
            Set( %ServiceAgreements, (
            Default => '2',
            Levels  => {
                '2' => {
                    StartImmediately => 1,
                    Response => { RealMinutes => 60 * 2 },
                },
                '4' => {
                    StartImmediately => 1,
                    Response => { RealMinutes => 60 * 4 },
                },
            },
        ));!
    ;
}

my $now = TIME;

my $queue = RT::Test->load_or_create_queue( Name => 'General', SLADisabled => 0 );

my $user = RT::Test->load_or_create_user(
    Name         => 'user',
    Password     => 'password',
    EmailAddress => 'user@example.com',
);

my ( $baseurl, $m ) = RT::Test->started_ok;
ok(
    RT::Test->set_rights(
        { Principal => $user, Right => [ qw(SeeQueue CreateTicket ShowTicket ModifyTicket ShowConfigTab AdminQueue) ] },
    ),
    'set rights'
);

ok $m->login( 'user', 'password' ), 'logged in as user';

{

    $m->goto_create_ticket( $queue->id );
    my $form = $m->form_name( 'TicketCreate' );
    my $sla  = $form->find_input( 'SLA' );
    is_deeply( [$sla->possible_values], [ 2, 4 ], 'possible sla' );
    $m->submit_form( fields => { Subject => 'ticket foo with default sla' }, button => 'SubmitTicket' );

    my $ticket = RT::Test->last_ticket;
    ok( $ticket->id, 'ticket is created' );
    my $id = $ticket->id;
    is( $ticket->SLA,             2,                  'default SLA is 2' );
    is( $ticket->StartsObj->Unix, $now,               'Starts' );
    is( $ticket->DueObj->Unix,    $now + 60 * 60 * 2, 'Due' );
}

{
    $m->goto_create_ticket( $queue->id );
    my $form = $m->form_name( 'TicketCreate' );
    $m->submit_form( fields => { Subject => 'ticket foo with default sla', SLA => 4 }, button => 'SubmitTicket' );

    my $ticket = RT::Test->last_ticket;
    ok( $ticket->id, 'ticket is created' );
    my $id = $ticket->id;
    is( $ticket->SLA,             4,                  'SLA is set to 4' );
    is( $ticket->StartsObj->Unix, $now,               'Starts' );
    is( $ticket->DueObj->Unix,    $now + 60 * 60 * 4, 'Due' );
    $m->follow_link_ok( { text => 'Jumbo' }, 'Ticket -> Jumbo' );
    $m->submit_form(
        form_name => 'TicketModifyAll',
        fields    => { SLA => 2 },
    );
    $ticket->Load( $id );
    is( $ticket->SLA, 2, 'SLA is set to 2' );
    is( $ticket->DueObj->Unix, $now + 60 * 60 * 2, 'Due is updated accordingly' );
}

{
    my $ticket = RT::Test->create_ticket( Queue => $queue->id, Subject => 'sla update', SLA => 4 );
    is( $ticket->SLA, 4, 'ticket has SLA 4, differing from the queue default 2' );

    for my $action (qw/Comment Respond/) {
        $m->get_ok( $baseurl . "/Ticket/Update.html?id=" . $ticket->id . "&Action=$action" );
        my $form = $m->form_name('TicketUpdate');
        is( $form->find_input('SLA')->value,
            4, "$action form defaults SLA to the ticket current SLA, not the queue default" );
    }

    $ticket->_Set( Field => 'SLA', Value => '', RecordTransaction => 0 );
    is( $ticket->SLA, '', 'ticket has no SLA set' );

    for my $action (qw/Comment Respond/) {
        $m->get_ok( $baseurl . "/Ticket/Update.html?id=" . $ticket->id . "&Action=$action" );
        my $form = $m->form_name('TicketUpdate');
        is( $form->find_input('SLA')->value, '', "$action form leaves SLA unset when the ticket has none" );
    }
}

{
    $m->get_ok( $baseurl . '/Admin/Queues/Modify.html?id=' . $queue->id );
    my $form = $m->form_name( 'ModifyQueue' );
    $m->untick( 'SLAEnabled', 1 );
    $m->submit;
    $m->text_contains( q{SLADisabled changed from (no value) to "1"} );
}

{

    $m->goto_create_ticket( $queue->id );
    my $form = $m->form_name( 'TicketCreate' );
    ok( !$form->find_input( 'SLA' ), 'no SLA input' );
    $m->submit_form( fields => { Subject => 'ticket foo without sla' }, button => 'SubmitTicket' );

    my $ticket = RT::Test->last_ticket;
    ok( $ticket->id,               'ticket is created' );
    ok( !$ticket->SLA,             'no SLA' );
    ok( !$ticket->StartsObj->Unix, 'no Starts' );
    ok( !$ticket->DueObj->Unix,    'no Due' );
}

done_testing;
