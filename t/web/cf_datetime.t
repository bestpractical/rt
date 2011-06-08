#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 51;

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
    $m->follow_link( id => 'tools-config-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'DateTime-1',
            LookupType    => 'RT::Queue-RT::Ticket',
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
    $m->follow_link( text => 'Ticket Custom Fields' );
    $m->title_is(q/Custom Fields for queue General/, 'admin-queue: general cfid');

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains('Object created', 'TCF added to the queue' );
}

diag 'check valid inputs with various timezones in ticket create page';
{
    my ( $ticket, $id );

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_contains('Select datetime', 'has cf field');

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test 2010-05-04 13:00:01',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-04 13:00:01',
        },
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

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test 2010-05-06 07:00:01',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-06 07:00:01',
        },
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
    $m->content_contains( '2010-05-04',     'got the right ticket' );
    $m->content_lacks( '2010-05-06', 'did not get the wrong ticket' );

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
    is_results_number( { $cf_op->name => '>', $cf_field->name => '2010-05-04', }, 2 );

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
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    my $form = $m->form_name("TicketCreate");

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => 'foodate',
        },
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $m->content_contains('test cf datetime:', 'has cf datetime field on the page');
    $m->content_lacks('foodate', 'invalid dates not set');
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

# to make $m->DESTROY happy
undef $m;

