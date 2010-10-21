#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use RT::Test tests => 14;


my ($baseurl, $m) = RT::Test->started_ok;
RT::Test->set_mail_catcher;

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
my $subject_tag = 'Windows/Servers-Desktops';
ok $queue && $queue->id, 'loaded or created queue';

diag "Set Subject Tag" if $ENV{'TEST_VERBOSE'};
{
    is(RT->System->SubjectTag($queue), undef, 'No Subject Tag yet');
    my ($status, $msg) = $queue->SetSubjectTag( $subject_tag );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
    is(RT->System->SubjectTag($queue), $subject_tag, "Set Subject Tag to $subject_tag");
}

my $original_ticket = RT::Ticket->new( $RT::SystemUser );
diag "Create a ticket and make sure it has the subject tag" if $ENV{'TEST_VERBOSE'};
{
    $original_ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost'
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = $entity->head->get('Subject');
        $subject =~ /\[\Q$subject_tag\E #\d+\]/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "Correctly added subject tag to ticket";
}


diag "Test that a reply with a Subject Tag doesn't change the subject" if $ENV{'TEST_VERBOSE'};
{
    my $ticketid = $original_ticket->Id;
    my $text = <<EOF;
From: root\@localhost
To: general\@$RT::rtname
Subject: [$subject_tag #$ticketid] test

reply with subject tag
EOF
    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => $queue->Name);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticketid, "Replied to ticket $id correctly");

    my $freshticket = RT::Ticket->new( $RT::SystemUser );
    $freshticket->LoadById($id);
    is($original_ticket->Subject,$freshticket->Subject,'Stripped Queue Subject Tag correctly');

}

diag "Test that a reply with another RT's subject tag changes the subject" if $ENV{'TEST_VERBOSE'};
{
    my $ticketid = $original_ticket->Id;
    my $text = <<EOF;
From: root\@localhost
To: general\@$RT::rtname
Subject: [$subject_tag #$ticketid] [remote-rt-system #79] test

reply with subject tag and remote rt subject tag
EOF
    diag($text);
    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => $queue->Name);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticketid, "Replied to ticket $id correctly");

    my $freshticket = RT::Ticket->new( $RT::SystemUser );
    $freshticket->LoadById($id);
    like($freshticket->Subject,qr/\[remote-rt-system #79\]/,"Kept remote rt's subject tag");
    unlike($freshticket->Subject,qr/\[\Q$subject_tag\E #$ticketid\]/,'Stripped Queue Subject Tag correctly');

}
