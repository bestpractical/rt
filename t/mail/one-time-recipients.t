#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use RT::Test tests => 38;

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name         => 'root',
    EmailAddress => 'root@localhost',
);
ok $user && $user->id, 'loaded or created user';

diag "Reply to ticket with actor as one time cc";
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    my ($status, undef, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost',
    );
    ok $status, "created ticket";

    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'root@localhost', 'got mail'
    }

    RT->Config->Set( NotifyActor => 1 );
    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'root@localhost', 'got mail'
    }

    RT->Config->Set( NotifyActor => 0 );
    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok !@mails, "no mail - don't notify actor";

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
        CcMessageTo => 'root@localhost',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('Cc');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'root@localhost', 'got mail'
    }
}

diag "Reply to ticket with requestor squelched";
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    my ($status, undef, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'test@localhost',
    );
    ok $status, "created ticket";

    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }

    $ticket->SquelchMailTo('test@localhost');
    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok !@mails, "no mail - squelched";

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
        CcMessageTo => 'test@localhost',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('Cc');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }
}

diag "Reply to ticket with requestor squelched";
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user ) );
    my ($status, undef, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'test@localhost',
    );
    ok $status, "created ticket";

    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
        SquelchMailTo => ['test@localhost'],
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok !@mails, "no mail - squelched";

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('To');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }

    ($status, $msg) = $ticket->Correspond(
        Content => 'test mail',
        CcMessageTo => 'test@localhost',
        SquelchMailTo => ['test@localhost'],
    );
    ok $status, "replied to a ticket";

    @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $to = $entity->head->get('Cc');
        $to =~ s/^\s+|\s+$//; 
        is $to, 'test@localhost', 'got mail'
    }
}
