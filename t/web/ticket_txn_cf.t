use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $cf_name = 'test txn cf';

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields    => {
            Name          => $cf_name,
            TypeComposite => 'Freeform-1',
            LookupType    => 'RT::Queue-RT::Ticket-RT::Transaction',
        },
    );
    $m->content_contains('Object created', 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "apply the CF to General queue";
my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

{
    $m->follow_link( id => 'admin-queues-select');
    $m->title_is( q/Admin queues/, 'admin-queues screen' );
    $m->follow_link( text => 'General' );
    $m->title_is( q/Configuration for queue General/,
        'admin-queue: general' );
    $m->follow_link( id => 'page-custom-fields-transactions' );
    $m->title_is( q/Custom Fields for queue General/,
        'admin-queue: general cfid' );

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains('Added custom field test txn cf to General.', 'TCF added to the queue' );
}

my ( $ticket, $id );
diag 'submit value on ticket create page';
{

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields    => { Queue => 'General' },
    );
    $m->content_contains($cf_name, 'has cf field' );

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                            => 'test 2017-01-04',
            Content                                            => 'test',
            "Object-RT::Transaction--CustomField-$cfid-Values" => 'hello from create',
        },
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/, "created ticket $id" );

    $ticket = RT::Ticket->new(RT->SystemUser);
    $ticket->Load($id);
    is( $ticket->Transactions->First->CustomFieldValues($cfid)->First->Content,
        'hello from create', 'txn cf value in db' );

    $m->content_contains($cf_name, 'has txn cf name on the page' );
    $m->content_contains('hello from create',
        'has txn cf value on the page' );
}

diag 'submit value on ticket update page';
{
    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );

    $m->content_contains($cf_name, 'has cf field' );

    $m->form_name('TicketUpdate');
    $m->field(UpdateContent => 'test 2');
    $m->field("Object-RT::Transaction--CustomField-$cfid-Values" => 'hello from update');
    $m->click('SubmitTicket');

    $m->content_contains('Correspondence added');

    my $txns = $ticket->Transactions;
    $txns->Limit(FIELD => 'Type', VALUE => 'Correspond');
    is( $txns->Last->CustomFieldValues($cfid)->First->Content,
        'hello from update', 'txn cf value in db' );

    $m->content_contains($cf_name, 'has txn cf name on the page' );
    $m->content_contains('hello from update',
        'has txn cf value on the page' );
}

diag 'submit no value on ticket update page';
{
    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );

    $m->content_contains($cf_name, 'has cf field' );

    $m->form_name('TicketUpdate');
    $m->field(UpdateContent => 'test 2');
    $m->click('SubmitTicket');

    $m->content_contains('Correspondence added');

    my $txns = $ticket->Transactions;
    $txns->Limit(FIELD => 'Type', VALUE => 'Correspond');
    is( $txns->Last->CustomFieldValues($cfid)->Count,
        0, 'no txn cf value in db' );
}

done_testing;

