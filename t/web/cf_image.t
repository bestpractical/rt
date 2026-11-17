use strict;
use warnings;
use utf8;

use RT::Test tests => 'no_declare';
use File::Copy ();
use File::Spec ();
use File::Temp ();
use URI::Escape ();

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


$m->submit_form( form_name => "CreateTicketInQueue" );
$m->content_contains("Upload one image");
$m->submit_form_ok({
    form_name => "TicketCreate",
    fields    => {
        Subject => 'Test ticket',
        Content => 'test',
    },
    button => 'SubmitTicket',
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

diag "Upload an image with a non-ASCII filename";
my $utf8_filename = "λογότυπο.png";
my $tmpdir        = File::Temp::tempdir( CLEANUP => 1 );
my $utf8_path     = File::Spec->catfile( $tmpdir, Encode::encode( 'UTF-8', $utf8_filename ) );
File::Copy::copy( RT::Test::get_relocatable_file( 'bpslogo.png', '..', 'data' ), $utf8_path )
    or die "Unable to copy bpslogo.png: $!";

$m->submit_form_ok({
    form_name => "TicketModify",
    fields    => {
        "Object-RT::Ticket-1-CustomField-2-Upload" => $utf8_path,
    },
    button => 'SubmitTicket',
});

my $ticket = RT::Ticket->new( RT->SystemUser );
$ticket->Load(1);
my $value = $ticket->CustomFieldValues($cfid)->First;
ok $value, 'Ticket has an Images value';
is $value->Content, $utf8_filename, 'Stored filename is the decoded non-ASCII filename';

my $link = $m->dom->at('a[href^="/Download/CustomFieldValue/' . $value->Id . '/"]');
ok $link, 'Found download link for the uploaded image';
is $link->text, $utf8_filename, 'Download link text is the non-ASCII filename';
is $link->attr('href'),
    '/Download/CustomFieldValue/' . $value->Id . '/' . URI::Escape::uri_escape_utf8($utf8_filename),
    'Download link URL encodes the filename as UTF-8';

done_testing;
