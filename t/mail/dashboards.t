#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 17;
use RT::Dashboard::Mailer;

my ($baseurl, $m) = RT::Test->started_ok;
RT::Test->set_mail_catcher;
ok($m->login, 'logged in');

# first, create and populate a dashboard
$m->get_ok('/Dashboards/Modify.html?Create=1');
$m->form_name('ModifyDashboard');
$m->field('Name' => 'Testing!');
$m->click_button(value => 'Create');
$m->title_is('Modify the dashboard Testing!');

$m->follow_link_ok({text => 'Content'});
$m->title_is('Modify the queries of dashboard Testing!');

my $form = $m->form_name('Dashboard-Searches-body');
my @input = $form->find_input('Searches-body-Available');
my ($dashboards_component) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ 'Dashboards' } @input;
$form->value('Searches-body-Available' => $dashboards_component );
$m->click_button(name => 'add');
$m->content_contains('Dashboard updated');

$m->follow_link_ok({text => 'Show'});
$m->title_is('Dashboard Testing!');
$m->content_contains('My dashboards');
$m->content_like(qr{<a href="/Dashboards/\d+/Testing!">Testing!</a>});

# now test the mailer

# without a subscription..
RT::Dashboard::Mailer->MailDashboards();

my @mails = RT::Test->fetch_caught_mails;
is @mails, 0, 'no mail yet';

RT::Dashboard::Mailer->MailDashboards(
    All => 1,
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 0, "no mail yet since there's no subscription";

# create a subscription
$m->follow_link_ok({text => 'Subscription'});
$m->title_is('Subscribe to dashboard Testing!');
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_contains("Subscribed to dashboard Testing!");

RT::Dashboard::Mailer->MailDashboards(
    All => 1,
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 1, "got a dashboard mail";

__END__


my $original_ticket = RT::Ticket->new( RT->SystemUser );
diag "Create a ticket and make sure it has the subject tag";
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


diag "Test that a reply with a Subject Tag doesn't change the subject";
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

    my $freshticket = RT::Ticket->new( RT->SystemUser );
    $freshticket->LoadById($id);
    is($original_ticket->Subject,$freshticket->Subject,'Stripped Queue Subject Tag correctly');

}

diag "Test that a reply with another RT's subject tag changes the subject";
{
    my $ticketid = $original_ticket->Id;
    my $text = <<EOF;
From: root\@localhost
To: general\@$RT::rtname
Subject: [$subject_tag #$ticketid] [remote-rt-system #79] test

reply with subject tag and remote rt subject tag
EOF
    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => $queue->Name);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticketid, "Replied to ticket $id correctly");

    my $freshticket = RT::Ticket->new( RT->SystemUser );
    $freshticket->LoadById($id);
    like($freshticket->Subject,qr/\[remote-rt-system #79\]/,"Kept remote rt's subject tag");
    unlike($freshticket->Subject,qr/\[\Q$subject_tag\E #$ticketid\]/,'Stripped Queue Subject Tag correctly');

}


