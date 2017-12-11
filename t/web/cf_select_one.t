
use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $cf_name = 'test select one value';

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'Select-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_contains('Object created', 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "add 'qwe', 'ASD', '0' and ' foo ' as values to the CF";
{
    foreach my $value(qw(qwe ASD 0), 'foo ') {
        $m->submit_form(
            form_name => "ModifyCustomField",
            fields => {
                "CustomField-". $cfid ."-Value-new-Name" => $value,
            },
            button => 'Update',
        );
        $m->content_contains('Object created', 'added a value to the CF' ); # or diag $m->content;
        my $v = $value;
        $v =~ s/^\s+$//;
        $v =~ s/\s+$//;
        $m->content_contains("value=\"$v\"", 'the added value is right' );
    }
}

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

diag "apply the CF to General queue";
{
    $m->follow_link( id => 'admin-queues');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( id => 'page-custom-fields-tickets');
    $m->title_is(q/Custom Fields for queue General/, 'admin-queue: general cfid');

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains("Added custom field $cf_name to General", 'TCF added to the queue' );
}

my $tid;
diag "create a ticket using API with 'asd'(not 'ASD') as value of the CF";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($txnid, $msg);
    ($tid, $txnid, $msg) = $ticket->Create(
        Subject => 'test',
        Queue => $queue->id,
        "CustomField-$cfid" => 'asd',
    );
    ok $tid, "created ticket";
    diag $msg if $msg;

    # we use lc as we really don't care about case
    # so if later we'll add canonicalization of value
    # test should work
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       'asd', 'assigned value of the CF';
}

diag "check that values of the CF are case insensetive(asd vs. ASD)";
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( id => 'page-basics');
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_contains($cf_name, 'CF on the page');

    my $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'correct value is selected';
    $m->submit;
    $m->content_unlike(qr/\Q$cf_name\E.*?changed/mi, 'field is not changed');

    $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'the same value is still selected';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       'asd', 'value is still the same';
}

diag "check that 0 is ok value of the CF";
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( id => 'page-basics');
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_contains($cf_name, 'CF on the page');

    my $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'correct value is selected';
    $m->select("Object-RT::Ticket-$tid-CustomField-$cfid-Values" => 0 );
    $m->submit;
    $m->content_like(qr/\Q$cf_name\E.*?changed/mi, 'field is changed');
    $m->content_lacks('0 is no longer a value for custom field', 'no bad message in results');

    $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, '0', 'new value is selected';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       '0', 'API returns correct value';
}

diag "check that we can set empty value when the current is 0";
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( id => 'page-basics');
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_contains($cf_name, 'CF on the page');

    my $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, '0', 'correct value is selected';
    $m->select("Object-RT::Ticket-$tid-CustomField-$cfid-Values" => '' );
    $m->submit;
    $m->content_contains('0 is no longer a value for custom field', '0 is no longer a value');

    $value = $m->form_name('TicketModify')->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is $value, '', '(no value) is selected';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->FirstCustomFieldValue( $cf_name ),
       undef, 'API returns correct value';
}

diag "check that a default value is displayed";
{
    my $default_ticket_id = RT::Test->create_ticket(Queue => 'General');
    $m->get_ok("/Ticket/Modify.html?id=" . $default_ticket_id->Id . "&CustomField-$cfid=qwe");
    $m->content_like(qr/\<option value="qwe"\s+selected="selected"/, 'Default value is selected');
}

diag 'retain selected cf values when adding attachments';
{
    my ( $ticket, $id );
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields    => { Queue => 'General' },
    );
    $m->content_contains($cf_name, 'Found cf field' );

    $m->submit_form_ok(
                       { form_name => "TicketCreate",
          fields    => {
              Subject        => 'test defaults',
              Content        => 'test',
              "Object-RT::Ticket--CustomField-$cfid-Values" => 'qwe',
            },
            button => 'AddMoreAttach',
        },
        'Add an attachment on create'
    );

    $m->form_name("TicketCreate");
    is($m->value("Object-RT::Ticket--CustomField-$cfid-Values"),
       "qwe",
       "Selected value still on form" );
}

done_testing;
