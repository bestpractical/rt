use warnings;
use strict;

use RT::Test tests => undef;
use File::Temp 'tempfile';

my $content = 'a' x 1000 . 'b' x 10;
my ( $fh, $path ) = tempfile( UNLINK => 1, SUFFIX => '.txt' );
print $fh $content;
close $fh;

my $name = ( File::Spec->splitpath($path) )[2];

RT->Config->Set( 'WebSessionClass', "Apache::Session::File");
RT->Config->Set( 'MaxAttachmentSize', 1000 );
RT->Config->Set( 'TruncateLongAttachments', '0' );
RT->Config->Set( 'DropLongAttachments',     '1' );

my $cf = RT::CustomField->new( RT->SystemUser );
ok(
    $cf->Create(
        Name  => 'test truncation',
        Queue => '0',
        Type  => 'FreeformSingle',
    ),
);
my $cfid = $cf->id;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "Loaded General queue" );
$m->get_ok( $baseurl . '/Ticket/Create.html?Queue=' . $queue->id );
$m->content_contains( "Create a new ticket", 'ticket create page' );

$m->form_name('TicketCreate');
$m->field( 'Subject', 'Attachments dropping test' );
$m->field( 'Attach',  $path );
$m->field( 'Content', 'Some content' );
my $cf_content = 'cf' . 'a' x 998 . 'cfb';
$m->field( "Object-RT::Ticket--CustomField-$cfid-Value", $cf_content );
$m->submit;
is( $m->status, 200, "request successful" );

$m->content_contains( "File '$name' dropped because its size (1010 bytes) exceeded configured maximum size setting (1000 bytes).", 'dropped message' );
$m->content_lacks( 'cfaaaa', 'cf value was dropped' );
$m->follow_link_ok( { text => "Download $name" } );
is( $m->content, 'Large attachment dropped', 'dropped $name' );

done_testing;
