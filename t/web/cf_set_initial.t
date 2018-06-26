use strict;
use warnings;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

my $cf = RT::CustomField->new( RT->SystemUser );
my ($cfid, $msg) = $cf->Create(
    Name => 'Test Set Initial CF',
    Queue => '0',
    Type => 'FreeformSingle',
);

my $multi_cf = RT::CustomField->new( RT->SystemUser );
my ($multi_cfid) = $multi_cf->Create(
    Name => 'Multi Set Initial CF',
    Queue => '0',
    Type => 'FreeformMultiple',
);

my $tester = RT::Test->load_or_create_user( Name => 'tester', Password => '123456' );
RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket)],
    },
);
ok $m->login( $tester->Name, 123456, logout => 1), 'logged in';

diag "check that we have no CFs on the create"
    ." ticket page when user has no SetInitialCustomField right";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_lacks('Test Set Initial CF', 'has no CF input');
    $m->content_lacks('Multi Set Initial CF', 'has no CF input');

    my $form = $m->form_name("TicketCreate");
    my $edit_field = "Object-RT::Ticket--CustomField-$cfid-Value";
    ok !$form->find_input( $edit_field ), 'no form field on the page';
    my $multi_field = "Object-RT::Ticket--CustomField-$multi_cfid-Values";
    ok !$form->find_input( $multi_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $m->content_lacks('Test Set Initial CF', 'has no CF on the page');
    $m->content_lacks('Multi Set Initial CF', 'has no CF on the page');
    $m->follow_link( text => 'Custom Fields');
    $m->content_lacks('Test Set Initial CF', 'has no CF field');
    $m->content_lacks('Multi Set Initial CF', 'has no CF field');
}

RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket SetInitialCustomField)],
    },
);

diag "check that we have the CF on the create"
    ." ticket page when user has SetInitialCustomField but no SeeCustomField";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_contains('Test Set Initial CF', 'has CF input');
    $m->content_contains('Multi Set Initial CF', 'has CF input');

    my $form = $m->form_name("TicketCreate");
    my $edit_field = "Object-RT::Ticket--CustomField-$cfid-Value";
    ok $form->find_input( $edit_field ), 'has form field on the page';
    my $multi_field = "Object-RT::Ticket--CustomField-$multi_cfid-Values";
    ok $form->find_input( $multi_field ), 'has form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => {
            $edit_field => 'yatta',
            $multi_field => 'hiro',
            Subject => 'test 2',
        },
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");
    if (my ($id) = $m->content =~ /Ticket (\d+) created/) {
        my $ticket = RT::Ticket->new(RT->SystemUser);
        my ($ok, $msg) = $ticket->Load($id);
        ok($ok, "loaded ticket $id");
        is($ticket->Subject, 'test 2', 'subject is correct');
        is($ticket->FirstCustomFieldValue('Test Set Initial CF'), 'yatta', 'CF was set correctly');
        is($ticket->FirstCustomFieldValue('Multi Set Initial CF'), 'hiro', 'CF was set correctly');
    }

    $m->content_lacks('Test Set Initial CF', 'has no CF on the page');
    $m->content_lacks('Multi Set Initial CF', 'has no CF on the page');
    $m->follow_link( text => 'Custom Fields');
    $m->content_lacks('Test Set Initial CF', 'has no CF edit field');
    $m->content_lacks('Multi Set Initial CF', 'has no CF edit field');
}

done_testing;
