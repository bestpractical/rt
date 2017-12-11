use strict;
use warnings;

use Data::ICal;
use RT::Test tests => undef;

my $start_obj = RT::Date->new( RT->SystemUser );
$start_obj->SetToNow;
my $start = $start_obj->iCal( Time => 1);

my $due_obj = RT::Date->new( RT->SystemUser );
$due_obj->SetToNow;
$due_obj->AddDays(2);
my $due = $due_obj->iCal( Time => 1);

diag 'Test iCal with date only';
{
    my ($baseurl, $agent) = RT::Test->started_ok;

    my $ticket = RT::Ticket->new(RT->SystemUser);

    for ( 1 .. 5 ) {
        $ticket->Create(
                        Subject   => 'Ticket ' . $_,
                        Queue     => 'General',
                        Owner     => 'root',
                        Requestor => 'ical@localhost',
                        Starts    => $start_obj->ISO,
                        Due       => $due_obj->ISO,
                       );
    }

    ok $agent->login('root', 'password'), 'logged in as root';

    $agent->get_ok('/Search/Build.html');
    $agent->form_name('BuildQuery');
    $agent->field('idOp', '>');
    $agent->field('ValueOfid', '0');
    $agent->submit('DoSearch');
    $agent->follow_link_ok({id => 'page-results'});

    for ( 1 .. 5 ) {
        $agent->content_contains('Ticket ' . $_);
    }

    $agent->follow_link_ok( { text => 'iCal' } );

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/Ticket\/Display\.html\?id=$_/);
    }

    my $ical = Data::ICal->new(data => $agent->content);

    my @entries = $ical->entries;
    my $ical_count = @{$entries[0]};
    is( $ical_count, 10, "Got $ical_count ical entries");

    my $prop_ref = $entries[0]->[0]->properties;
    my $start_as_root = RT::Date->new( RT::CurrentUser->new( 'root' ) );
    $start_as_root->Unix( $start_obj->Unix );
    my $start = $start_as_root->ISO( Time => 0, Timezone => 'user' );
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date: $start");
    like( $prop_ref->{'dtstart'}->[0]->as_string, qr/VALUE=DATE\:/, 'Got DATE value');

    $prop_ref = $entries[0]->[1]->properties;
    my $due_as_root = RT::Date->new( RT::CurrentUser->new( 'root' ) );
    $due_as_root->Unix( $due_obj->Unix );
    my $due = $due_as_root->ISO( Time => 0, Timezone => 'user' );
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date: $due");
    like( $prop_ref->{'dtend'}->[0]->as_string, qr/VALUE=DATE\:/, 'Got DATE value');
}

RT::Test->stop_server;

diag 'Test iCal with date and time with config option';
{
    RT->Config->Set(TimeInICal =>1);
    my ($baseurl, $agent) = RT::Test->started_ok;

    ok $agent->login('root', 'password'), 'logged in as root';

    $agent->get_ok('/Search/Build.html');
    $agent->form_name('BuildQuery');
    $agent->field('idOp', '>');
    $agent->field('ValueOfid', '0');
    $agent->submit('DoSearch');
    $agent->follow_link_ok({id => 'page-results'});

    for ( 1 .. 5 ) {
        $agent->content_contains('Ticket ' . $_);
    }

    my $link = $agent->find_link( text => 'iCal' ); # use $link later
    $agent->get_ok($link->url);

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/Ticket\/Display\.html\?id=$_/);
    }

    my $ical = Data::ICal->new(data => $agent->content);

    my @entries = $ical->entries;
    my $ical_count = @{$entries[0]};
    is( $ical_count, 10, "Got $ical_count ical entries");

    my $prop_ref = $entries[0]->[0]->properties;
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date with time: $start");
    like( $prop_ref->{'dtstart'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');

    $prop_ref = $entries[0]->[1]->properties;
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date with time: $due");
    like( $prop_ref->{'dtend'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');
}

RT::Test->stop_server;

diag 'Test iCal with date and time using query param';
{
    RT->Config->Set(TimeInICal =>0);
    my ($baseurl, $agent) = RT::Test->started_ok;

    ok $agent->login('root', 'password'), 'logged in as root';

    $agent->get_ok('/Search/Build.html');
    $agent->form_name('BuildQuery');
    $agent->field('idOp', '>');
    $agent->field('ValueOfid', '0');
    $agent->submit('DoSearch');
    $agent->follow_link_ok({id => 'page-results'});

    for ( 1 .. 5 ) {
        $agent->content_contains('Ticket ' . $_);
    }

    my $link = $agent->find_link( text => 'iCal' );
    $agent->get_ok($link->url . '?Time=1');

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/Ticket\/Display\.html\?id=$_/);
    }

    my $ical = Data::ICal->new(data => $agent->content);

    my @entries = $ical->entries;
    my $ical_count = @{$entries[0]};
    is( $ical_count, 10, "Got $ical_count ical entries");

    my $prop_ref = $entries[0]->[0]->properties;
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date with time: $start");
    like( $prop_ref->{'dtstart'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');

    $prop_ref = $entries[0]->[1]->properties;
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date with time: $due");
    like( $prop_ref->{'dtend'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');

    diag 'Test iCal with date and time in single events';

    my $url = $link->url . '?SingleEvent=1&Time=1';
    $agent->get_ok($url);

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/Ticket\/Display\.html\?id=$_/);
    }

    $ical = Data::ICal->new(data => $agent->content);

    @entries = $ical->entries;
    $ical_count = @{$entries[0]};

    # Only 5 entries in single event mode
    is( $ical_count, 5, "Got $ical_count ical entries");

    $prop_ref = $entries[0]->[0]->properties;
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date with time: $start");
    like( $prop_ref->{'dtstart'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');

    $prop_ref = $entries[0]->[1]->properties;
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date with time: $due");
    like( $prop_ref->{'dtend'}->[0]->as_string, qr/VALUE=DATE-TIME\:/, 'Got DATE-TIME value');
}

done_testing;
