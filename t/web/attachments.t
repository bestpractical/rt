use strict;
use warnings;

use RT::Test tests => undef;
use File::Spec ();
use MIME::Entity;
use JSON ();
use utf8;

# Lower both caps before the server starts so the new values are picked up
# for the bulk-download section below.
RT->Config->Set( MaxBulkAttachmentCount     => 2  );
RT->Config->Set( MaxBulkAttachmentTotalSize => 30 );

use constant LogoFile => $RT::StaticPath .'/images/bpslogo.png';
use constant FaviconFile => $RT::StaticPath .'/images/favicon.png';
use constant TextFile => $RT::StaticPath .'/css/mobile.css';
use constant CalendarFile => RT::Test::get_relocatable_file( 'invite.ics', ( File::Spec->updir(), 'data' ) );

my ($url, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue && $queue->id, "Loaded General queue" );

# Helper: create a ticket via SystemUser with an attachment whose MIME
# filename is $name. Returns ($ticket, $attachment_with_name).
sub _create_ticket_with_attachment {
    my (%args)   = @_;
    my $subject  = $args{Subject}  // 'attachment test';
    my $filename = $args{Filename} // 'foo.txt';

    my $mime = MIME::Entity->build(
        From    => 'test@example.com',
        Subject => $subject,
        Type    => 'text/plain',
        Data    => ['initial body'],
    );
    $mime->attach(
        Type     => 'text/plain',
        Filename => $filename,
        Data     => ["attachment body for $filename"],
    );

    my $ticket = RT::Test->create_ticket( Queue => $queue, Subject => $subject, MIMEObj => $mime );

    my $atts = RT::Attachments->new( RT->SystemUser );
    $atts->LimitByTicket( $ticket->Id );
    $atts->Limit( FIELD => 'Filename', VALUE => $filename );
    my $att = $atts->First;
    ok( $att && $att->Id, "found attachment $filename on ticket " . $ticket->Id );
    return ( $ticket, $att );
}

diag "create a ticket in full interface";
diag "w/o attachments";
{
    $m->goto_create_ticket( $queue );
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->content_contains("Create a new ticket", 'ticket create page');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_lacks('attachment-search', 'search/sort/filter controls are hidden when there are no attachments');
    $m->content_lacks('attachment-bulk-toggle', 'Bulk icon is hidden when there are no attachments');
}

diag "with one attachment";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Subject', 'Attachments test');
    $m->field('Attach',  LogoFile);
    $m->field('Content', 'Some content');

    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    $m->content_contains('attachment-search', 'search/sort/filter controls are shown when there are attachments');
    $m->content_contains('attachment-bulk-toggle', 'Bulk icon is shown when there are attachments');
}

diag "with two attachments";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

SKIP: {
    skip "delete attach function is ajaxified, no checkbox anymore", 8;

diag "with one attachment, but delete one along the way";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->tick( 'DeleteAttach', LogoFile );
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

diag "with one attachment, but delete one along the way";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->tick( 'DeleteAttach', LogoFile );
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

}

diag "reply to a ticket in full interface";
diag "with one attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

diag "with two attachments";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

SKIP: {
    skip "delete attach function is ajaxified, no checkbox anymore", 4;
diag "with one attachment, delete one along the way";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketUpdate');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}
}

diag "jumbo interface";
diag "with one attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

diag "with two attachments";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketModifyAll');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

SKIP: {
    skip "delete attach function is ajaxified, no checkbox anymore", 4;
diag "with one attachment, delete one along the way";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketModifyAll');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}
}

diag "bulk update";
diag "one attachment";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
        ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    }
}

diag "two attachments";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('BulkUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
        ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    }
}

SKIP: {
    skip "delete attach function is ajaxified, no checkbox anymore", 8;
diag "one attachment, delete one along the way";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('BulkUpdate');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
        ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    }
}
}

diag "self service";
diag "create with attachment";
{
    $m->get_ok( $url . "/SelfService/Create.html?Queue=". $queue->id );

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->field('Subject', 'Subject');
    $m->field('Content', 'Message');
    ok($m->current_form->find_input('AddMoreAttach'), "more than one attachment");
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

diag "update with attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->get_ok( $url . "/SelfService/Update.html?id=". $ticket->id );
    $m->form_name('TicketUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    ok($m->current_form->find_input('AddMoreAttach'), "more than one attachment");
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );
}

diag "mobile ui";

diag "simple create + reply";
{
    $m->get_ok( $url . '/m/ticket/create?Queue=' . $queue->id );

    $m->form_name('TicketCreate');
    $m->field('Subject', 'Attachments test');
    $m->field('Attach',  LogoFile);
    $m->field('Content', 'Some content');
    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('bpslogo.png', 'page has file name');

    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('bpslogo.png', 'page has file name');
    $m->content_contains('favicon.png', 'page has file name');
}


diag "check content type and content";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  TextFile);
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    ok( $m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    ok( $m->find_link( text => 'mobile.css', url_regex => qr{Attachment/} ), 'page has the file link' );

    $m->follow_link_ok( { url_regex => qr/Attachment\/\d+\/\d+\/bpslogo\.png/ } );
    is($m->response->header('Content-Type'), 'image/png', 'Content-Type of png lacks charset' );
    is($m->content_type, "image/png");
    is($m->content, RT::Test->file_content(LogoFile), "Binary content matches");
    $m->back;

    $m->follow_link_ok( { url_regex => qr/Attachment\/\d+\/\d+\/mobile\.css/ } );
    is( $m->response->header('Content-Type'),
        'text/css;charset=UTF-8',
        'Content-Type of text has charset',
    );
    is($m->content_type, "text/css");
    is($m->content, RT::Test->file_content(TextFile), "Text content matches");
}

diag "concurent actions";
my $m2 = RT::Test::Web->new;
ok $m2->login, 'second login';

diag "update and create";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m2->goto_ticket( $ticket->id );
    $m2->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m2->form_name('TicketUpdate');
    $m2->field('Attach',  LogoFile);
    $m2->click('AddMoreAttach');
    is($m2->status, 200, "request successful");

    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    ok( !$m->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );
    ok( $m->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page has the file link' );

    $m2->form_name('TicketUpdate');
    $m2->click('SubmitTicket');
    ok( $m2->find_link( text => 'bpslogo.png', url_regex => qr{Attachment/} ), 'page has the file link' );
    ok( !$m2->find_link( text => 'favicon.png', url_regex => qr{Attachment/} ), 'page lacks the file link' );

}

diag "Calendar attachments";
{
    $m->goto_create_ticket($queue);

    $m->form_name('TicketCreate');
    $m->field( 'Attach',  CalendarFile );
    $m->field( 'Subject', 'Attachments test' );
    $m->field( 'Content', 'Some content' );
    $m->click('SubmitTicket');
    is( $m->status, 200, "request successful" );

    ok( $m->find_link( text => 'invite.ics', url_regex => qr{Attachment/} ), 'page has the file link' );
    my %headers = (
        'Type'          => 'Invitation to a meeting',
        'From'          => 'alice@example.com',
        'Subject'       => '测试标题',
        'Location'      => 'New York',
        'Starting'      => 'Wed Apr 19 04:00:00 2023 America/New_York',
        'Ending'        => 'Wed Apr 19 05:00:00 2023 America/New_York',
        'Attendees'     => 'alice@example.com, bob@example.com, richard@example.com',
        'Last Modified' => 'Wed Apr 19 03:39:19 2023',
    );

    for my $tag ( sort keys %headers ) {
        $m->text_contains("$tag: $headers{$tag}");
    }

    $m->content_contains( '<b><u>这是说明</u></b>', 'found html description' );
}

# Two 10-byte rows + one 25-byte row on a single ticket lets us exercise:
#   * over the count cap: 3 ids
#   * over the size cap via accumulation: 10 + 25 = 35 > 30 (count still ≤ 2)
#   * under both caps: 10 + 10 = 20 ≤ 30 (count 2 ≤ 2)
my $bulk_ticket = RT::Test->create_ticket( Queue => $queue->Name, Subject => 'bulk dl' );

my %sizes = ( 'one.txt' => 10, 'two.txt' => 10, 'big.txt' => 25 );
my ( @small_ids, $big_id );
for my $name ( sort keys %sizes ) {
    my $mime = MIME::Entity->build( Type => 'text/plain', Filename => $name, Data => [ 'x' x $sizes{$name} ] );
    my ($txn_id) = $bulk_ticket->AddAttachment( MIMEObj => $mime );
    ok( $txn_id, "added attachment $name" );

    my $atts = RT::Attachments->new( RT->SystemUser );
    $atts->Limit( FIELD => 'TransactionId', VALUE => $txn_id );
    my $att = $atts->First;
    if ( $name eq 'big.txt' ) { $big_id = $att->Id }
    else                      { push @small_ids, $att->Id }
}

diag 'Bulk download: requesting more attachments than MaxBulkAttachmentCount returns 413';
{
    my $query = join '&', map {"ids=$_"} @small_ids, $big_id;
    my $req   = $m->get( $url . "/Ticket/Attachment/Bulk?$query" );
    is( $req->code, 413, 'over the count cap returns 413 (HTTP_REQUEST_ENTITY_TOO_LARGE)' );
    like( $req->decoded_content, qr/maximum is 2/, 'response mentions the count cap' );

    $m->next_warning_like( qr/Bulk attachment download rejected:\s+requested 3 attachments, limit is 2/,
        'logged warning about exceeded count cap' );
    $m->next_warning_like( qr/Too many attachments selected \(maximum is 2\)/,
        'logged the Abort message as a warning' );
}

diag 'Bulk download: requesting attachments whose total bytes exceed MaxBulkAttachmentTotalSize returns 413';
{
    my $query = join '&', map {"ids=$_"} ( $small_ids[0], $big_id );
    my $req   = $m->get( $url . "/Ticket/Attachment/Bulk?$query" );
    is( $req->code, 413, 'over the size cap returns 413 (HTTP_REQUEST_ENTITY_TOO_LARGE)' );
    like( $req->decoded_content, qr/maximum total size of 30/, 'response mentions the size cap' );

    $m->next_warning_like( qr/Bulk attachment download rejected:\s+total size exceeds 30 bytes/,
        'logged warning about exceeded size cap' );
    $m->next_warning_like( qr/Selected attachments exceed the maximum total size of 30 bytes/,
        'logged the Abort message as a warning' );
}

diag 'Bulk download: under both caps returns a proper zip response';
{
    my $query = join '&', map {"ids=$_"} @small_ids;
    my $req   = $m->get( $url . "/Ticket/Attachment/Bulk?$query" );
    is( $req->code,                   200,               'under both caps returns 200' );
    is( $req->header('Content-Type'), 'application/zip', 'returns application/zip' );
    like( $req->header('Content-Disposition') // '',
        qr/attachment; filename=rt-attachments\.zip/, 'Content-Disposition is a zip attachment' );
}

diag 'ProcessTicketAttachments rejects DeleteAttachments from another ticket';
{
    my ($ticket_a) = _create_ticket_with_attachment( Filename => 'web_a.txt' );
    ( undef, my $att_b ) = _create_ticket_with_attachment( Filename => 'web_b.txt' );

    my $att_b_id = $att_b->Id;

    my $req = $m->post( $url . "/Helpers/TicketUpdate", { id => $ticket_a->Id, DeleteAttachments => $att_b_id }, );
    is( $req->code, 200, "cross-ticket DeleteAttachments POST returned 200" );

    my $data = JSON::from_json( $req->decoded_content );
    ok( $data && ref( $data->{actions} ) eq 'ARRAY', 'response has actions array' );
    my @actions = @{ $data->{actions} };
    ok( ( grep {/Invalid attachment #\Q$att_b_id\E/} @actions ), "actions include 'Invalid attachment #$att_b_id'" )
        or diag "actions: " . join( ' | ', @actions );

    my $check = RT::Attachment->new( RT->SystemUser );
    $check->Load($att_b_id);
    ok( $check->Id, 'cross-ticket attachment still exists after rejected delete' );
    is( $check->Filename, 'web_b.txt', 'cross-ticket attachment Filename unchanged' );
}

diag 'ProcessTicketAttachments rejects RenameAttachment-N from another ticket';
{
    my ($ticket_a) = _create_ticket_with_attachment( Filename => 'web_rename_a.txt' );
    ( undef, my $att_b ) = _create_ticket_with_attachment( Filename => 'web_rename_b.txt' );

    my $att_b_id = $att_b->Id;
    my $req      = $m->post(
        $url . "/Helpers/TicketUpdate",
        { id => $ticket_a->Id, "RenameAttachment-$att_b_id" => 'pwned.txt' },
    );
    is( $req->code, 200, "cross-ticket Rename POST returned 200" );

    my $data    = JSON::from_json( $req->decoded_content );
    my @actions = @{ $data->{actions} || [] };
    ok( ( grep {/Invalid attachment #\Q$att_b_id\E/} @actions ),
        "actions include 'Invalid attachment #$att_b_id' for cross-ticket rename" );

    my $check = RT::Attachment->new( RT->SystemUser );
    $check->Load($att_b_id);
    is( $check->Filename, 'web_rename_b.txt', 'cross-ticket attachment Filename unchanged' );
}

diag 'ProcessTicketAttachments rejects PinAttachments / UnpinAttachments from another ticket';
{
    my ($ticket_a) = _create_ticket_with_attachment( Filename => 'web_pin_a.txt' );
    my ( $ticket_b, $att_b ) = _create_ticket_with_attachment( Filename => 'web_pin_b.txt' );

    my $att_b_id = $att_b->Id;

    my $req = $m->post( $url . "/Helpers/TicketUpdate", { id => $ticket_a->Id, PinAttachments => $att_b_id }, );
    is( $req->code, 200, "cross-ticket Pin POST returned 200" );

    my $data    = JSON::from_json( $req->decoded_content );
    my @actions = @{ $data->{actions} || [] };
    ok( ( grep {/Invalid attachment #\Q$att_b_id\E/} @actions ),
        "cross-ticket Pin rejected with Invalid attachment message" );

    my @pinned_b = $ticket_b->PinnedAttachments;
    is( scalar @pinned_b, 0, 'ticket B has no pinned attachments after cross-ticket Pin attempt' );

    $req = $m->post( $url . "/Helpers/TicketUpdate", { id => $ticket_a->Id, UnpinAttachments => $att_b_id }, );
    is( $req->code, 200, "cross-ticket Unpin POST returned 200" );

    $data    = JSON::from_json( $req->decoded_content );
    @actions = @{ $data->{actions} || [] };
    ok( ( grep {/Invalid attachment #\Q$att_b_id\E/} @actions ),
        "cross-ticket Unpin rejected with Invalid attachment message" );
}

done_testing;
