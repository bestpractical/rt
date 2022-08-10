
use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( 'Timezone' => 'EST5EDT' ); # -04:00
my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new( RT->SystemUser );
ok( $root->Load('root'), 'load root user' );

my $cf_name = 'test cf datetime';

my $why;

if ( ( $ENV{RT_TEST_WEB_HANDLER} || '' ) =~ /^apache(\+mod_perl)?$/
    && RT::Test::Apache->apache_mpm_type =~ /^(?:worker|event)$/ )
{
    $why =
'localizing $ENV{TZ} does *not* work with mod_perl+mpm_event or mod_perl+mpm_worker';
}

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'DateTime-1',
            LookupType    => 'RT::Queue-RT::Ticket',
            EntryHint     => 'Select datetime',
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
    $m->follow_link( text => 'Queues' );
    $m->title_is(q/Admin queues/, 'admin-queues screen');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( id => 'page-custom-fields-tickets' );
    $m->title_is(q/Custom Fields for queue General/, 'admin-queue: general cfid');

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains("Added custom field $cf_name to General", 'TCF added to the queue' );
}

diag 'check valid inputs with various timezones in ticket create page';
{
    my ( $ticket, $id );

    $m->submit_form( form_name => "CreateTicketInQueue" );
    $m->content_contains('Select datetime', 'has cf field');

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test 2010-05-04 13:00:01',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-04 13:00:01',
        },
        button => 'SubmitTicket',
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/,
        "created ticket $id" );

    $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    TODO: {
        local $TODO = $why;
        is(
            $ticket->CustomFieldValues($cfid)->First->Content,
            '2010-05-04 17:00:01',
            'date in db is in UTC'
        );
    }

    $m->content_contains('test cf datetime:', 'has cf datetime field on the page');
    $m->content_contains('Tue May 04 13:00:01 2010', 'has cf datetime value on the page');

    $root->SetTimezone( 'Asia/Shanghai' );
    # interesting that $m->reload doesn't work
    $m->get_ok( $m->uri );

    TODO: {
        local $TODO = $why;
        $m->content_contains( 'Wed May 05 01:00:01 2010',
            'cf datetime value respects user timezone' );
    }

    $m->submit_form( form_name => "CreateTicketInQueue" );
    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test 2010-05-06 07:00:01',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-06 07:00:01',
        },
        button => 'SubmitTicket',
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/,
        "created ticket $id" );
    $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    TODO: {
        local $TODO = $why;
        is(
            $ticket->CustomFieldValues($cfid)->First->Content,
            '2010-05-05 23:00:01',
            'date in db is in UTC'
        );
    }

    $m->content_contains('test cf datetime:', 'has cf datetime field on the page');
    $m->content_contains( 'Thu May 06 07:00:01 2010',
        'cf datetime input respects user timezone' );
    $root->SetTimezone( 'EST5EDT' ); # back to -04:00
    $m->get_ok( $m->uri );

    TODO: {
        local $TODO = $why;
        $m->content_contains( 'Wed May 05 19:00:01 2010',
            'cf datetime value respects user timezone' );
    }
}

diag 'check ticket clone feature';
{
    $m->follow_link_ok( { text => 'Create', url_regex => qr/RefersTo-new=/ } );
    TODO: {
        local $TODO = $why;
        $m->text_contains( 'Wed May 05 19:00:01 2010',
            'cf datetime value in ticket clone form respects user timezone' );
    }

    $m->submit_form(form_name => "TicketCreate", button => 'SubmitTicket');
    $m->text_like( qr/Ticket (\d+) created/, 'ticket created' );

    TODO: {
        local $TODO = $why;
        $m->text_contains( 'Wed May 05 19:00:01 2010',
            'cf datetime value respects user timezone' );
    }
}

diag 'check ticket edit page';
{
    my $ticket = RT::Test->last_ticket;
    my $id = $ticket->Id;
    $m->follow_link_ok( { text => 'Basics' } );
    $m->submit_form(
        form_name => 'TicketModify',
        fields    => {
            "Object-RT::Ticket-$id-CustomField-$cfid-Values" => '2010-05-06 15:00:01',
        },
        button => 'SubmitTicket',
    );
    TODO: {
        local $TODO = $why;
        $m->text_contains("$cf_name Wed May 05 19:00:01 2010 changed to Thu May 06 15:00:01 2010");
    }

    $m->submit_form(
        form_name => 'TicketModify',
        fields    => {
            "Object-RT::Ticket-$id-CustomField-$cfid-Values" => '2021-06-07 15:05:10',
        },
        button => 'SubmitTicket',
    );
    # no matter if localizing $ENV{TZ} works or not, the old value is always "2010-05-06 15:00:01" to user
    $m->text_contains("$cf_name Thu May 06 15:00:01 2010 changed to Mon Jun 07 15:05:10 2021");
}

diag 'check search build page';
{
    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );

    $m->form_name('BuildQuery');
    my ($cf_op) =
      $m->find_all_inputs( type => 'option', name_regex => qr/test cf datetime/ );
    is_deeply(
        [ $cf_op->possible_values ],
        [ '<', '=', '>' ],
        'right oprators'
    );

    my ($cf_field) =
      $m->find_all_inputs( type => 'text', name_regex => qr/test cf datetime/ );

    is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-04', }, 1 );
    like($m->dom->at('table.ticket-list')->all_text, qr/2010-05-04/, 'got the right ticket');
    unlike($m->dom->at('table.ticket-list')->all_text, qr/2010-05-06/, 'did not get the wrong ticket');

    my $shanghai = RT::Test->load_or_create_user(
        Name     => 'shanghai',
        Password => 'password',
        Timezone => 'Asia/Shanghai',
    );
    ok( $shanghai->PrincipalObj->GrantRight(
        Right  => 'SuperUser',
        Object => $RT::System,
    ));
    $m->login( 'shanghai', 'password', logout => 1 );

    is_results_number( { $cf_op->name => '<', $cf_field->name => '2010-05-07', }, 2 );
    is_results_number( { $cf_op->name => '>', $cf_field->name => '2010-05-04', }, 3 );

    TODO: {
        local $TODO = $why;
        is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-05', }, 1 );
        is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-05 01:00:01', }, 1 );
    }

    is_results_number(
        { $cf_op->name => '=', $cf_field->name => '2010-05-05 02:00:01', }, 0 );

    is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-06', }, 1 );
    is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-06 07:00:01', }, 1 );
    is_results_number( { $cf_op->name => '=', $cf_field->name => '2010-05-06 08:00:01', }, 0 );
}

diag 'check invalid inputs';
{
    $m->submit_form( form_name => "CreateTicketInQueue" );
    my $form = $m->form_name("TicketCreate");

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => 'foodate',
        },
        button => 'SubmitTicket',
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $m->content_contains('test cf datetime:', 'has cf datetime field on the page');
    $m->content_lacks('foodate', 'invalid dates not set');

    my @warnings = $m->get_warnings;
    chomp @warnings;
    is_deeply(
        [ @warnings ],
        [
            (
                q{Couldn't parse date 'foodate' by Time::ParseDate},
                q{Couldn't parse date 'foodate' by DateTime::Format::Natural}
            ) x 2
        ]
    );
}

diag 'retain values when adding attachments';
{
    my ( $ticket, $id );

    my $txn_cf = RT::CustomField->new( RT->SystemUser );
    my ( $ret, $msg ) = $txn_cf->Create(
        Name          => 'test txn cf datetime',
        TypeComposite => 'DateTime-1',
        LookupType    => 'RT::Queue-RT::Ticket-RT::Transaction',
    );
    ok( $ret, "created 'txn datetime': $msg" );
    $txn_cf->AddToObject(RT::Queue->new(RT->SystemUser));
    my $txn_cfid = $txn_cf->id;

    $m->submit_form( form_name => "CreateTicketInQueue" );
    $m->content_contains('test cf datetime', 'has cf' );
    $m->content_contains('test txn cf datetime', 'has txn cf' );

    $m->submit_form_ok(
        {
            form_name => "TicketCreate",
            fields    => {
                Subject => 'test 2015-06-04',
                Content => 'test',
                "Object-RT::Ticket--CustomField-$cfid-Values" => '2015-06-04 08:30:00',
                "Object-RT::Transaction--CustomField-$txn_cfid-Values" => '2015-08-15 12:30:30',
            },
            button => 'AddMoreAttach',
        },
        'Create test ticket'
    );
    $m->form_name("TicketCreate");
    is( $m->value( "Object-RT::Ticket--CustomField-$cfid-Values" ),
        "2015-06-04 08:30:00", "ticket cf date value still on form" );
    $m->content_contains( "Jun 04 08:30:00 2015", 'date in parens' );
    is( $m->value( "Object-RT::Transaction--CustomField-$txn_cfid-Values" ),
        "2015-08-15 12:30:30", "txn cf date date value still on form" );
    $m->content_contains( "Aug 15 12:30:30 2015", 'date in parens' );

    $m->submit_form( button => 'SubmitTicket' );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/, "Created ticket $id" );

    $m->follow_link_ok( {text => 'Reply'} );
    $m->title_like( qr/Update/ );
    $m->content_contains('test txn cf date', 'has txn cf');
    $m->submit_form_ok(
        {
            form_name => "TicketUpdate",
            fields    => {
                Content => 'test',
                "Object-RT::Transaction--CustomField-$txn_cfid-Values" => '2015-09-16 09:30:40',
            },
            button => 'AddMoreAttach',
        },
        'Update test ticket'
    );
    $m->form_name("TicketUpdate");
    is( $m->value( "Object-RT::Transaction--CustomField-$txn_cfid-Values" ),
        "2015-09-16 09:30:40", "Date value still on form" );
    $m->content_contains( "Sep 16 09:30:40 2015", 'date in parens' );

    $m->follow_link_ok( {text => 'Jumbo'} );
    $m->title_like( qr/Jumbo/ );

    $m->submit_form_ok(
        {
            form_name => "TicketModifyAll",
            fields    => {
                "Object-RT::Transaction--CustomField-$txn_cfid-Values" =>
                  '2015-12-16 03:00:00',
            },
            button => 'AddMoreAttach',
        },
        'jumbo form'
    );

    $m->form_name("TicketModifyAll");
    is( $m->value( "Object-RT::Transaction--CustomField-$txn_cfid-Values" ),
        "2015-12-16 03:00:00", "txn date value still on form" );
    $m->content_contains( "Dec 16 03:00:00 2015", 'date in parens' );
}

sub is_results_number {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $fields = shift;
    my $number = shift;
    my $operator = shift;
    my $value = shift;
    {
        local $TODO;
        $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    }
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => $fields,
        button => 'DoSearch',
    );
    $m->content_contains( "Found $number ticket", "Found $number ticket" );
}

done_testing;
