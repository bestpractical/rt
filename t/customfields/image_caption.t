#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 33;

my ($baseurl, $agent) =RT::Test->started_ok;
ok( $agent->login, 'log in' );

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('General');
my $img_cf = RT::CustomField->new($RT::SystemUser);

my ($val,$msg) = $img_cf->Create(Name => 'ImgOne', Type =>'ImageWithCaption', LookupType => 'RT::Queue-RT::Ticket', MaxValues => 1);

ok($val,$msg);
my $cf_id = $val;
$img_cf->AddToObject($q);
use_ok('RT');

my $cf;
diag "load and check basic properties of the img CF" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = RT::CustomFields->new( $RT::SystemUser );
    $cfs->Limit( FIELD => 'Name', VALUE => 'ImgOne' );
    is( $cfs->Count, 1, "found one CF with name 'ImgOne'" );

    $cf = $cfs->First;
    is( $cf->Type, 'ImageWithCaption', 'type check' );
    is( $cf->LookupType, 'RT::Queue-RT::Ticket', 'lookup type check' );
    is( $cf->MaxValues, 1 );
    ok( !$cf->Disabled, "not disabled" );
}

diag "check that CF applies to queue General" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = $q->TicketCustomFields;
    $cfs->Limit( FIELD => 'id', VALUE => $cf->id, ENTRYAGGREGATOR => 'AND' );
    is( $cfs->Count, 1, 'field applies to queue' );
}

diag "create a ticket via web and set image with catpion" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test img',
            "$cf_field-Upload" => 'share/html/NoAuth/images/bpslogo.png',
            "$cf_field-Value" => 'Foo image',
        }
    );

    $agent->content_like( qr/Foo image/, "image caption on the page" );
    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('ImgOne'), 'Foo image',
        'correct value' );
}


diag "create a ticket via web and set image with catpion" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test img',
            "$cf_field-Upload" => 'share/html/NoAuth/images/bpslogo.png',
            "$cf_field-Value" => '',
        }
    );

    $agent->content_like( qr/bpslogo.png/, "default caption on the page" );
    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('ImgOne'), 'bpslogo.png',
        'correct value' );
}



my $last_id;
diag "create a ticket via web and leave the image empty" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test without img',
        }
    );

    $agent->content_like( qr/test without img/, "created" );
    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    $last_id = $id;
}



diag "go to last ticket and create the image with caption cf" if $ENV{'TEST_VERBOSE'};
{
    my $id = $last_id;
    diag $id;
    ok $agent->goto_ticket($id), "go to last ticket";
    $agent->follow_link_ok( { text => 'Basics' });
    $agent->content_like( qr/test without img/, "found ticket" );

    my $cf_field = "Object-RT::Ticket-$id-CustomField-$cf_id";
    $agent->submit_form_ok( {
        form_name => 'TicketModify',
        fields    => {
            id => $id, # XXX: why is this needed? shouldn't mechanize keeps the value of the hidden fields?
            "$cf_field-Upload" => 'share/html/NoAuth/images/bpslogo.png',
            "$cf_field-Value" => 'Foo image',
        } });

    $agent->content_like( qr/Foo image/, "image caption on the page" );
    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('ImgOne'), 'Foo image',
        'correct value' );

}
