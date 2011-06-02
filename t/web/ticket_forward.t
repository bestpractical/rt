#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 30;
use File::Temp 'tempfile';
use File::Spec;
my ( $att_fh, $att_file ) =
  tempfile( 'rttestXXXXXX', SUFFIX => '.txt', UNLINK => 1, TMPDIR => 1 );
print $att_fh "this is an attachment";
close $att_fh;
my $att_name = ( File::Spec->splitpath($att_file) )[-1];

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

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

diag "Foward Ticket" if $ENV{TEST_VERBOSE};
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

diag "Foward Transaction" if $ENV{TEST_VERBOSE};
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

diag "Foward Ticket without content" if $ENV{TEST_VERBOSE};
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
}

