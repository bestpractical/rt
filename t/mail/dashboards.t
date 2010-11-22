#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 27;
use RT::Dashboard::Mailer;

my ($baseurl, $m) = RT::Test->started_ok;
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
$m->field('Frequency' => 'daily');
$m->field('Hour' => '06:00');
$m->click_button(name => 'Save');
$m->content_contains("Subscribed to dashboard Testing!");

RT::Dashboard::Mailer->MailDashboards(
    All => 1,
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 1, "got a dashboard mail";
my $mail = parse_mail( $mails[0] );
is($mail->head->get('Subject'), "[example.com] Daily Dashboard: Testing!\n");

SKIP: {
    skip 'Weird MIME failure', 2;
    my $body = $mail->stringify_body;
    like($body, qr{My dashboards});
    like($body, qr{<a href="/Dashboards/\d+/Testing!">Testing!</a>});
};

RT::Dashboard::Mailer->MailDashboards(
    All    => 1,
    DryRun => 1,
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 0, "no mail because it's a dry run";


RT::Dashboard::Mailer->MailDashboards(
    Time => 1290337260, # 6:01 EST on a monday
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 1, "got a dashboard mail";
$mail = parse_mail( $mails[0] );
is($mail->head->get('Subject'), "[example.com] Daily Dashboard: Testing!\n");

SKIP: {
    skip 'Weird MIME failure', 2;
    my $body = $mail->stringify_body;
    like($body, qr{My dashboards});
    like($body, qr{<a href="/Dashboards/\d+/Testing!">Testing!</a>});
};

RT::Dashboard::Mailer->MailDashboards(
    Time   => 1290337260, # 6:01 EST on a monday
    DryRun => 1,
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 0, "no mails because of DryRun";


RT::Dashboard::Mailer->MailDashboards(
    Time => 1290340860, # 7:01 EST on a monday
);

@mails = RT::Test->fetch_caught_mails;
is @mails, 0, "no mail because it's the wrong time";

