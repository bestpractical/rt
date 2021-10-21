use strict;
use warnings;

use RT::Test tests => undef;

use constant LogoFile => $RT::StaticPath .'/images/bpslogo.png';
use constant FaviconFile => $RT::StaticPath .'/images/favicon.png';
use constant TextFile => $RT::StaticPath .'/css/mobile.css';

my ($url, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue && $queue->id, "Loaded General queue" );

diag "create a ticket in full interface";
diag "w/o attachments";
{
    $m->goto_create_ticket( $queue );
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->content_contains("Create a new ticket", 'ticket create page');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");
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

done_testing;
