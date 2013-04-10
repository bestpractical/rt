
use strict;
use warnings;

use RT::Test nodata => 1, tests => 47;
use RT::Ticket;
use RT::CustomField;

my $queue_name = "CFSortQueue-$$";
my $queue = RT::Test->load_or_create_queue( Name => $queue_name );
ok($queue && $queue->id, "$queue_name - test queue creation");

diag "create a CF";
my $cf_name = "Rights$$";
my $cf;
{
    $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field Order created");
}

my $tester = RT::Test->load_or_create_user(
    Name => 'tester', Password => 'password',
);
ok $tester && $tester->id, 'loaded or created user';

my $cc_role = $queue->RoleGroup( 'Cc' );
my $owner_role = $queue->RoleGroup( 'Owner' );

ok( RT::Test->set_rights(
    { Principal => $tester, Right => [qw(SeeQueue ShowTicket CreateTicket ReplyToTicket Watch OwnTicket TakeTicket)] },
    { Principal => $cc_role, Object => $queue, Right => [qw(SeeCustomField)] },
    { Principal => $owner_role, Object => $queue, Right => [qw(ModifyCustomField)] },
), 'set rights');

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test' );
    ok $tid, "created ticket";

    ok !$ticket->CustomFields->First, "see no fields";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    my $cf = $ticket->CustomFields->First;
    ok $cf, "Ccs see cf";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok !$status, "Can not change CF";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->Name ), 'test';

    ($status, $msg) = $ticket->DeleteCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->Name ), undef;
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->id, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->id ), 'test';

    ($status, $msg) = $ticket->DeleteCustomFieldValue( Field => $cf->id, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->id ), undef;
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login( tester => 'password' ), 'logged in';

diag "check that we don't have the cf on create";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => $queue->Name },
    );

    my $form = $m->form_name("TicketCreate");
    my $cf_field = "Object-RT::Ticket--CustomField-". $cf->id ."-Value";
    ok !$form->find_input( $cf_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    my ($tid) = ($m->content =~ /Ticket (\d+) created/i);
    ok $tid, "created a ticket succesfully";
    $m->content_lacks($cf_name, "don't see CF");

    $m->follow_link( id => 'page-basics');
    $form = $m->form_name('TicketModify');
    $cf_field = "Object-RT::Ticket-$tid-CustomField-". $cf->id ."-Value";
    ok !$form->find_input( $cf_field ), 'no form field on the page';
}

diag "check that we see CF as Cc";
{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_contains($cf_name, "see CF");
}

diag "check that owner can see and edit CF";
{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_contains($cf_name, "see CF");

    $m->follow_link( id => 'page-basics');
    my $form = $m->form_name('TicketModify');
    my $cf_field = "Object-RT::Ticket-$tid-CustomField-". $cf->id ."-Value";
    ok $form->find_input( $cf_field ), 'form field on the page';

    $m->submit_form(
        form_name => 'TicketModify',
        fields => {
            $cf_field => "changed cf",
        },
    );

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_contains($cf_name, "changed cf");
}

note 'make sure CF is not reset to no value';
{
    my $t = RT::Test->create_ticket(
        Queue => $queue->id,
        Subject => 'test',
        'CustomField-'.$cf->id => '2012-02-12',
        Cc => $tester->id,
        Owner => $tester->id,
    );
    ok $t && $t->id, 'created ticket';
    is $t->FirstCustomFieldValue($cf_name), '2012-02-12';

    $m->goto_ticket($t->id);
    $m->follow_link_ok({id => 'page-basics'});
    my $form = $m->form_name('TicketModify');
    my $input = $form->find_input(
        'Object-RT::Ticket-'. $t->id .'-CustomField-'. $cf->id .'-Value'
    );
    ok $input, 'found input';
    $m->click('SubmitTicket');

    my $tid = $t->id;
    $t = RT::Ticket->new( $RT::SystemUser );
    $t->Load( $tid );
    is $t->FirstCustomFieldValue($cf_name), '2012-02-12';
}

