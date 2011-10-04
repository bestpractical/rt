#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => undef;
use File::Spec;
my $att_file = File::Spec->catfile( RT::Test->temp_directory, 'attachment' );
open my $att_fh, '>', $att_file or die $!;
print $att_fh "this is an attachment";
close $att_fh;
my $att_name = ( File::Spec->splitpath($att_file) )[-1];

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Create a ticket with content and an attachment
$m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

$m->submit_form(
    form_name => 'TicketCreate',
    fields    => {
        Subject => 'test forward',
        Content => 'this is content',
        Attach  => $att_file,
    },
);
$m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
RT::Test->clean_caught_mails;

diag "Forward Ticket" if $ENV{TEST_VERBOSE};
{
    $m->follow_link_ok(
        { id => 'page-actions-forward' },
        'follow 1st Forward to forward ticket'
    );

    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To => 'rt-test, rt-to@example.com',
            Cc => 'rt-cc@example.com',
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    $m->content_contains(
        'Forwarded Ticket to rt-test, rt-to@example.com, rt-cc@example.com',
        'txn msg' );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr!Subject: test forward!,           'Subject field' );
    like( $mail, qr!To: rt-test, rt-to\@example.com!, 'To field' );
    like( $mail, qr!Cc: rt-cc\@example.com!,          'Cc field' );
    like( $mail, qr!This is a forward of ticket!,     'content' );
    like( $mail, qr!this is an attachment!,           'att content' );
    like( $mail, qr!$att_name!,                       'att file name' );
}

diag "Forward Transaction" if $ENV{TEST_VERBOSE};
{
    $m->follow_link_ok( { text => 'Forward', n => 2 }, 'follow 2nd Forward' );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To  => 'rt-test, rt-to@example.com',
            Cc  => 'rt-cc@example.com',
            Bcc => 'rt-bcc@example.com'
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    $m->content_like(
qr/Forwarded Transaction #\d+ to rt-test, rt-to\@example.com, rt-cc\@example.com, rt-bcc\@example.com/,
        'txn msg'
    );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr!Subject: test forward!,            'Subject field' );
    like( $mail, qr!To: rt-test, rt-to\@example.com!,  'To field' );
    like( $mail, qr!Cc: rt-cc\@example.com!,           'Cc field' );
    like( $mail, qr!Bcc: rt-bcc\@example.com!,         'Bcc field' );
    like( $mail, qr!This is a forward of transaction!, 'content' );
    like( $mail, qr!$att_name!,                        'att file name' );
    like( $mail, qr!this is an attachment!,            'att content' );
}

diag "Forward Ticket without content" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Test->create_ticket(
        Subject => 'test forward without content',
        Queue   => 1,
    );
    $m->get_ok( $baseurl . '/Ticket/Forward.html?id=' . $ticket->id );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => { To => 'rt-test@example.com', },
        button    => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr/Subject: Fwd: \[example\.com #\d\] test forward without content/, 'Subject field' );
    like( $mail, qr/To: rt-test\@example\.com/,             'To field' );
    like( $mail, qr/This is a forward of ticket #\d/,       'content' );
}

diag "Forward Transaction with attachments but empty content" if $ENV{TEST_VERBOSE};
{
    # Create a ticket without content but with a non-text/plain attachment
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->form_name('TicketCreate');
    my $attach = $m->current_form->find_input('Attach');
    $attach->filename("awesome.patch");
    $attach->headers('Content-Type' => 'text/x-diff');
    $m->set_fields(
        Subject => 'test forward, empty content but attachments',
        Attach  => $att_file, # from up top
    );
    $m->click('AddMoreAttach');
    $m->form_name('TicketCreate');
    $attach = $m->current_form->find_input('Attach');
    $attach->filename("bpslogo.png");
    $attach->headers('Content-Type' => 'image/png');
    $m->set_fields(
        Attach  => RT::Test::get_relocatable_file('bpslogo.png', '..', 'data'), # an image!
    );
    $m->submit;
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->content_like( qr/awesome\.patch/,   'uploaded patch file' );
    $m->content_like( qr/text\/x-diff/,     'uploaded patch file content type' );
    $m->content_like( qr/bpslogo\.png/,     'uploaded image file' );
    $m->content_like( qr/image\/png/,       'uploaded image file content type' );
    RT::Test->clean_caught_mails;

    $m->follow_link_ok( { text => 'Forward', n => 2 }, 'follow 2nd Forward' );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To  => 'rt-test@example.com',
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    $m->content_like( qr/Forwarded Transaction #\d+ to rt-test\@example\.com/, 'txn msg' );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr/Subject: test forward, empty content but attachments/, 'Subject field' );
    like( $mail, qr/To: rt-test\@example.com/,         'To field' );
    like( $mail, qr/This is a forward of transaction/, 'content' );
    like( $mail, qr/awesome\.patch/,                   'att file name' );
    like( $mail, qr/this is an attachment/,            'att content' );
    like( $mail, qr/text\/x-diff/,                     'att content type' );
    like( $mail, qr/bpslogo\.png/,                     'att image file name' );
    like( $mail, qr/image\/png/,                       'att image content type' );
}

diag "Forward Transaction with attachments but no 'content' part" if $ENV{TEST_VERBOSE};
{
    my $mime = MIME::Entity->build(
        From    => 'test@example.com',
        Subject => 'attachments for everyone',
        Type    => 'multipart/mixed',
    );

    $mime->attach(
        Path        => $att_file,
        Type        => 'text/x-diff',
        Filename    => 'awesome.patch',
        Disposition => 'attachment',
    );
    
    $mime->attach(
        Path        => RT::Test::get_relocatable_file('bpslogo.png', '..', 'data'),
        Type        => 'image/png',
        Filename    => 'bpslogo.png',
        Encoding    => 'base64',
        Disposition => 'attachment',
    );

    my $ticket = RT::Test->create_ticket(
        Queue   => 1,
        Subject => 'test forward, attachments but no "content"',
        MIMEObj => $mime,
    );

    $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $ticket->Id );
    $m->content_like( qr/awesome\.patch/,   'uploaded patch file' );
    $m->content_like( qr/text\/x-diff/,     'uploaded patch file content type' );
    $m->content_like( qr/bpslogo\.png/,     'uploaded image file' );
    $m->content_like( qr/image\/png/,       'uploaded image file content type' );
    RT::Test->clean_caught_mails;

    # Forward txn
    $m->follow_link_ok( { text => 'Forward', n => 2 }, 'follow 2nd Forward' );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To  => 'rt-test@example.com',
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    $m->content_like( qr/Forwarded Transaction #\d+ to rt-test\@example\.com/, 'txn msg' );
    
    # Forward ticket
    $m->follow_link_ok( { text => 'Forward', n => 1 }, 'follow 1st Forward' );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To  => 'rt-test@example.com',
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Sent email successfully', 'sent mail msg' );
    $m->content_like( qr/Forwarded Ticket to rt-test\@example\.com/, 'txn msg' );

    my ($forward_txn, $forward_ticket) = RT::Test->fetch_caught_mails;
    my $tag = qr/Fwd: \[example\.com #\d+\]/;
    like( $forward_txn, qr/Subject: $tag attachments for everyone/, 'Subject field is from txn' );
    like( $forward_txn, qr/This is a forward of transaction/, 'forward description' );
    like( $forward_ticket, qr/Subject: $tag test forward, attachments but no "content"/, 'Subject field is from ticket' );
    like( $forward_ticket, qr/This is a forward of ticket/, 'forward description' );

    for my $mail ($forward_txn, $forward_ticket) {
        like( $mail, qr/To: rt-test\@example.com/,         'To field' );
        like( $mail, qr/awesome\.patch/,                   'att file name' );
        like( $mail, qr/this is an attachment/,            'att content' );
        like( $mail, qr/text\/x-diff/,                     'att content type' );
        like( $mail, qr/bpslogo\.png/,                     'att image file name' );
        like( $mail, qr/image\/png/,                       'att image content type' );
    }
}

undef $m;
done_testing;
