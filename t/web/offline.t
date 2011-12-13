#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 20;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

{
    my $template = <<EOF;
===Create-Ticket: ticket1
Queue: General
Subject: test
Status: new
EOF
    my $ticket = create_ticket_offline( $m, $template );
    ok $ticket->id, 'created a ticket with offline tool';
    is $ticket->QueueObj->Name, 'General', 'correct value';
    is $ticket->Subject, 'test', 'correct value';
    is $ticket->Status, 'new', 'correct value';
}

{
    my $template = <<'EOF';
===Create-Ticket: ticket1
Queue: General
Subject: test
Status: new
Requestor: test@example.com
EOF
    my $ticket = create_ticket_offline( $m, $template );
    ok $ticket->id, 'created a ticket with offline tool';
    is $ticket->RequestorAddresses, 'test@example.com', 'correct value';
}

{
    my $group = RT::Group->new(RT->SystemUser);
    my ($id, $msg) = $group->CreateUserDefinedGroup( Name => 'test' );
    ok $id, "created a user defined group";

    my $template = <<'EOF';
===Create-Ticket: ticket1
Queue: General
Subject: test
Status: new
Requestor: test@example.com
RequestorGroup: test
EOF
    my $ticket = create_ticket_offline( $m, $template );
    ok $ticket->id, 'created a ticket with offline tool';
    ok grep(
        { $_->MemberId eq $group->id }
        @{ $ticket->Requestors->MembersObj->ItemsArrayRef }
    ), 'correct value' ;
    is $ticket->RequestorAddresses, 'test@example.com', 'correct value';
}

sub create_ticket_offline {
    my ($m, $template) = @_;

    $m->get_ok( $url . '/Tools/Offline.html' );

    $m->submit_form(
        form_name => 'TicketUpdate',
        fields    => { string => $template },
        button    => 'UpdateTickets',
    );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $m->content_like( qr/Ticket \d+ created/, 'found ticket created message' )
        or return $ticket;

    $ticket->Load( $m->content =~ /Ticket (\d+) created/ );
    return $ticket;
}


