#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 6;
use File::Temp qw/tempfile/;
use Encode;
use RT::Ticket;

my ( $url, $m ) = RT::Test->started_ok;
$m->default_header( 'Accept-Language' => "zh-cn" );
ok( $m->login, 'logged in' );

my $ticket_id;
my $template;

{

    # test create message
    $template = <<EOF;
===Create-Ticket: ticket1
Queue: General
Subject: test message
Status: new
Content: 
ENDOFCONTENT
Due: 
TimeEstimated: 100
TimeLeft: 100
FinalPriority: 90
EOF

    $m->get_ok( $url . '/Tools/Offline.html' );

    $m->submit_form(
        form_name => 'TicketUpdate',
        fields    => { string => $template, },
        button    => 'UpdateTickets',
    );
    my $content = encode 'utf8', $m->content;
    ok( $content =~ qr/申请单 #(\d+) 成功新增于 &#39;General&#39; 表单/, 'message is shown right' );
    $ticket_id = $1;
}

{

    # test update message
    $template = <<EOF;
===Update-Ticket: 1
Subject: test message update
EOF

    $m->get_ok( $url . '/Tools/Offline.html' );
    $m->submit_form(
        form_name => 'TicketUpdate',
        fields    => { string => $template, },
        button    => 'UpdateTickets',
    );

    my $content = encode 'utf8', $m->content;
    ok(
        $content =~
qr/主题\s*的值从\s*&#39;test message&#39;\s*改为\s*&#39;test message update&#39;/,
        'subject is updated'
    );
}

