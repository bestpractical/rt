#!/usr/bin/perl

use strict;
use warnings;

use RT::Test strict => 1, tests => 34, l10n => 1;


my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $cf_name = 'test select one value';
my $cf_moniker = 'edit-ticket-cfs';

diag "Create a CF" if $ENV{'TEST_VERBOSE'};

my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
my ( $status, $msg ) = $cf->create(
    name        => $cf_name,
    type        => 'Select',
    lookup_type => 'RT::Model::Queue-RT::Model::Ticket',
    max_values  => 1,
);
ok( $status, $msg );
my $cfid = $cf->id;


diag "add 'qwe', 'ASD' and '0' as values to the CF" if $ENV{'TEST_VERBOSE'};
{
    foreach my $value(qw(qwe ASD 0)) {
        my ( $status, $msg ) = $cf->add_value( name => $value );
        ok( $status, $msg );
    }
}

my $queue = RT::Test->load_or_create_queue( name => 'General' );
ok $queue && $queue->id, 'loaded or Created queue';

diag "apply the CF to General queue" if $ENV{'TEST_VERBOSE'};
$cf->add_to_object( $queue );


my $tid;
diag "create a ticket using API with 'asd'(not 'ASD') as value of the CF"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    my ($txnid, $msg);
    ($tid, $txnid, $msg) = $ticket->create(
        subject => 'test',
        queue => $queue->id,
        "cf_$cfid" => 'ASD',
    );
    ok $tid, "Created ticket";
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};

    # we use lc as we really don't care about case
    # so if later we'll add canonicalization of value
    # test should work
    is lc $ticket->first_custom_field_value( $cf_name ),
       'asd', 'assigned value of the CF';
}

diag "check that values of the CF are case insensetive(asd vs. ASD)"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( url_regex => qr{Ticket/Modify.html} );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is lc $value, 'asd', 'correct value is selected';
    $m->submit;
    $m->content_unlike(qr/\Q$cf_name\E.*?changed/mi, 'field is not changed');

    $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is lc $value, 'asd', 'the same value is still selected';
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->first_custom_field_value( $cf_name ),
       'asd', 'value is still the same';
}

diag "check that 0 is ok value of the CF"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( url_regex => qr{Ticket/Modify.html} );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is lc $value, 'asd', 'correct value is selected';
    $m->select("J:A:F-$cfid-$cf_moniker" => 0 );
    $m->submit;
    $m->content_like(qr/\Q$cf_name\E.*?changed/mi, 'field is changed');
    $m->content_unlike(qr/0 is no longer a value for custom field/mi, 'no bad message in results');

    $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is lc $value, '0', 'new value is selected';

    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->first_custom_field_value( $cf_name ),
       '0', 'API returns correct value';
}

diag "check that we can set empty value when the current is 0"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( url_regex => qr{Ticket/Modify.html} );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is lc $value, '0', 'correct value is selected';
    $m->select("J:A:F-$cfid-$cf_moniker" => '' );
    $m->submit;
    $m->content_like(qr/0 is no longer a value for custom field/mi, '0 is no longer a value');

    $value = $m->form_name('ticket_modify')->value("J:A:F-$cfid-$cf_moniker");
    is $value, '', '(no value) is selected';

    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->first_custom_field_value( $cf_name ),
       undef, 'API returns correct value';
}

