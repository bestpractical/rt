#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 9;
use utf8;

use Encode;

use RT::Ticket;
my $file = File::Spec->catfile( RT::Test->temp_directory, 'template' );
open my $fh, '>', $file or die $!;
my $template = <<EOF;
===Create-Ticket: ticket1
Queue: General
Subject: 标题
Status: new
Content: 
这是正文
ENDOFCONTENT
EOF

print $fh $template;
close $fh;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . '/Tools/Offline.html' );

$m->submit_form(
    form_name => 'TicketUpdate',
    fields    => { Template => $file, },
    button    => 'Parse',
);

$m->content_contains( '这是正文', 'content is parsed right' );

$m->submit_form(
    form_name => 'TicketUpdate',
    button    => 'UpdateTickets',

    # mimic what browsers do: they seems decoded $template
    fields    => { string => $template },
);

$m->content_like( qr/Ticket \d+ created/, 'found ticket created message' );
my ( $ticket_id ) = $m->content =~ /Ticket (\d+) created/;

my $ticket = RT::Ticket->new( RT->SystemUser );
$ticket->Load( $ticket_id );
is( $ticket->Subject, '标题', 'subject in $ticket is right' );

$m->goto_ticket($ticket_id);
$m->content_contains( '这是正文',
    'content is right in ticket display page' );

