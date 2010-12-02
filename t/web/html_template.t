#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 19;
use Encode;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

use utf8;

diag('make Autoreply template a html one and add utf8 chars')
  if $ENV{TEST_VERBOSE};

{
    $m->follow_link_ok( { id => 'tools-config-global-templates' },     '-> Templates' );
    $m->follow_link_ok( { text => 'Autoreply' },     '-> Autoreply' );

    $m->submit_form(
        form_name => 'ModifyTemplate',
        fields => {
            Content => <<'EOF',
Subject: AutoReply: {$Ticket->Subject}
Content-Type: text/html

你好 éèà€
{$Ticket->Subject}
-------------------------------------------------------------------------
{$Transaction->Content()}

EOF
        },
    );
    $m->content_like( qr/Content changed/, 'content is changed' );
    $m->content_contains( '你好', 'content is really updated' );
}

diag('create a ticket to see the autoreply mail') if $ENV{TEST_VERBOSE};

{
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->submit_form(
        form_name => 'TicketCreate',
        fields      => { Subject => '标题', Content => '<h1>测试</h1>',
        ContentType => 'text/html' },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->follow_link( text => 'Show' );
    $m->content_contains( '你好',    'html has 你好' );
    $m->content_contains( 'éèà€', 'html has éèà€' );
    $m->content_contains( '标题',
        'html has ticket subject 标题' );
    $m->content_contains( '&lt;h1&gt;测试&lt;/h1&gt;',
        'html has ticket html content 测试' );
}

diag('test real mail outgoing') if $ENV{TEST_VERBOSE};

{

    # $mail is utf8 encoded
    my ($mail) = RT::Test->fetch_caught_mails;
    $mail = decode_utf8 $mail;
    like( $mail, qr/你好.*你好/s,    'mail has éèà€' );
    like( $mail, qr/éèà€.*éèà€/s, 'mail has éèà€' );
    like( $mail, qr/标题.*标题/s,    'mail has ticket subject 标题' );
    like( $mail, qr/测试.*测试/s,    'mail has ticket content 测试' );
    like( $mail, qr!<h1>测试</h1>!,    'mail has ticket html content 测试' );
}

