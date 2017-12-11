use strict;
use warnings;

use RT::Test tests => 'no_declare';

my (undef, $m) = RT::Test->started_ok;
$m->login;
$m->follow_link( id => 'admin-custom-fields-create' );
$m->submit_form_ok({
    form_name => "ModifyCustomField",
    fields    => {
        Name          => 'Images',
        TypeComposite => 'Image-1',
        LookupType    => 'RT::Queue-RT::Ticket',
        EntryHint     => 'Upload one image',
    },
});
$m->content_contains("Object created");
my $cfid = $m->form_name('ModifyCustomField')->value('id');
ok $cfid, "Created CF correctly";

$m->follow_link_ok( {id => "page-applies-to"} );
$m->form_with_fields( "AddCustomField-2" );
$m->tick( "AddCustomField-2", 0 );
$m->click_ok( "UpdateObjs" );
$m->content_contains("Globally added custom field Images");


$m->submit_form_ok({
    form_name => "CreateTicketInQueue",
    fields    => { Queue => 'General' },
});
$m->content_contains("Upload one image");
$m->submit_form_ok({
    form_name => "TicketCreate",
    fields    => {
        Subject => 'Test ticket',
        Content => 'test',
    },
});
$m->content_like( qr/Ticket \d+ created/,
                  "a ticket is created succesfully" );

$m->follow_link_ok( {id => "page-basics"} );
$m->content_contains("Upload one image");
$m->submit_form_ok({
    form_name => "TicketModify",
    fields    => {
        "Object-RT::Ticket-1-CustomField-2-Upload" =>
            RT::Test::get_relocatable_file('bpslogo.png', '..', 'data'),
    },
});
$m->content_contains("bpslogo.png added");
$m->content_contains("/Download/CustomFieldValue/1/bpslogo.png");

$m->form_name("TicketModify");
$m->tick("Object-RT::Ticket-1-CustomField-2-DeleteValueIds", 1);
$m->click_ok("SubmitTicket");
$m->content_lacks("/Download/CustomFieldValue/1/bpslogo.png");

done_testing;
