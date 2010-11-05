#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 19;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

RT::Test->set_mail_catcher;
$m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

$m->submit_form(
    form_name   => 'TicketCreate',
    fields      => {
        Subject => 'test forward',
        Content => 'this is content',
    },
);
$m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
RT::Test->clean_caught_mails;

diag "Foward Ticket" if $ENV{TEST_VERBOSE};
{
    $m->follow_link_ok( { id => 'page-transitions-forward'},
        'follow 1st Forward to forward ticket' );

    $m->submit_form(
        form_name   => 'ForwardMessage',
        fields      => {
            To  => 'rt-test, rt-to@example.com',
            Cc  => 'rt-cc@example.com',
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Send email successfully', 'sent mail msg' );
    $m->content_contains(
'Forwarded Ticket to rt-test, rt-to@example.com, rt-cc@example.com',
        'txn msg'
    );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr!Subject: test forward!, 'Subject field' );
    like( $mail, qr!To: rt-test, rt-to\@example.com!, 'To field' );
    like( $mail, qr!Cc: rt-cc\@example.com!, 'Cc field' );
    like( $mail, qr!This is a forward of ticket!, 'content' );
}

diag "Foward Transaction" if $ENV{TEST_VERBOSE};
{
    $m->follow_link_ok( { text => 'Forward', n => 2 }, 'follow 2nd Forward' );
    $m->submit_form(
        form_name   => 'ForwardMessage',
        fields      => {
            To  => 'rt-test, rt-to@example.com',
            Cc  => 'rt-cc@example.com',
            Bcc => 'rt-bcc@example.com'
        },
        button => 'ForwardAndReturn'
    );
    $m->content_contains( 'Send email successfully', 'sent mail msg' );
    $m->content_like(
qr/Forwarded Transaction #\d+ to rt-test, rt-to\@example.com, rt-cc\@example.com, rt-bcc\@example.com/,
        'txn msg'
    );
    my ($mail) = RT::Test->fetch_caught_mails;
    like( $mail, qr!Subject: test forward!, 'Subject field' );
    like( $mail, qr!To: rt-test, rt-to\@example.com!, 'To field' );
    like( $mail, qr!Cc: rt-cc\@example.com!, 'Cc field' );
    like( $mail, qr!Bcc: rt-bcc\@example.com!, 'Bcc field' );
    like( $mail, qr!This is a forward of transaction!, 'content' );
}

