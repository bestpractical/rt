use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_tickets(
    {   Queue   => 'General',
        Subject => 'Requestor order test',
        Content => 'test',
    },
    { Requestor => 'alice@localhost', },
    { Requestor => 'richard@localhost', },
    { Requestor => 'bob@localhost', },
);

for my $cf_type (qw/Freeform Date DateTime/) {
    my $cf = RT::Test->load_or_create_custom_field(
        Name       => "${cf_type}Example",
        Type       => $cf_type,
        Queue      => 0,
        LookupType => 'RT::Queue-RT::Ticket',
    );
    ok $cf && $cf->id, "Created $cf_type custom field";
}

ok $m->login, 'logged in';

$m->get_ok('/Search/Results.html?Query=id>0');
$m->follow_link_ok( { text => 'Requestor' } );
$m->text_like( qr/alice.*bob.*richard/i, 'Order by Requestors ASC' );
$m->follow_link_ok( { text_regex => qr/Requestor/ } );
$m->text_like( qr/richard.*bob.*alice/i, , 'Order by Requestors DESC' );

diag "Test extended status column map when 'UseSQLForACLChecks' is false";
{
    RT::Test->stop_server;
    RT->Config->Set( '$UseSQLForACLChecks' => 0 );
    ( $baseurl, $m ) = RT::Test->started_ok;

    my $queue_a = RT::Test->load_or_create_queue( Name => 'A' );
    ok $queue_a && $queue_a->id, 'loaded or created queue_a';
    my $qa_id = $queue_a->id;

    my $user_a = RT::Test->load_or_create_user(
        Name => 'user_a', Password => 'password', Privileged => 1
    );
    ok $user_a && $user_a->id, 'loaded or created user';
    my $m_user_a = RT::Test::Web->new;
    ok( $m_user_a->login( 'user_a', 'password' ), 'logged in as user_a' );

    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Requestor', Right => [qw(ShowTicket)] },
    );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue     => 'A',
        Subject   => 'Parent Ticket',
        Requestor => 'dave@localost',
    );
    ok $id;

    # Create ticket with DependsOn relationship
    (my $new_id, $txn, $msg) = $ticket->Create(
        Queue     => 'A',
        Subject   => 'Child Ticket',
        Requestor => 'user_a',
        DependsOn => $id
    );

    # Do a search with extended status column but the logged in user can only see
    # the DependedOn ticket.
    $m_user_a->get_ok( "/Search/Results.html?Query=id>0&Format='__id__','__ExtendedStatus__'" );
    $m_user_a->content_lacks('Invalid column', 'No invalid column map results from extended status');
}

diag 'Test date columns for calendar display mode';
{
    ok $m->login, 'logged in';
    $m->get_ok("/Search/Calendar.html?Query=id>0&Format='__id__', CF.FreeformExample");
    $m->content_contains( 'No date columns were found' );

    for my $field (qw/Created Starts Started Due LastUpdated Resolved/) {
        for my $column ( $field, "${field}Relative", "__${field}__", "__${field}Relative__" ) {
            $m->get_ok("/Search/Calendar.html?Query=id>0&Format='__id__', $column");
            $m->content_lacks( 'No date columns were found', "Date column $column works" );
        }
    }

    for my $field (qw/DateExample DateTimeExample/) {
        for my $column (
            "CF.$field",                    "CF.{$field}",
            "CustomField.$field",           "CustomField.{$field}",
            "__CF.${field}__",              "__CF.{$field}__",
            "__CustomField.${field}__",     "__CustomField.{$field}__",
            "CustomFieldView.$field",       "CustomFieldView.{$field}",
            "__CustomFieldView.${field}__", "__CustomFieldView.{$field}__",
            )
        {
            $m->get_ok("/Search/Calendar.html?Query=id>0&Format='__id__', $column");
            $m->content_lacks( 'No date columns were found', "Date column $column works" );
        }
    }
}

done_testing;
