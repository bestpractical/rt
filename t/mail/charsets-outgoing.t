#!/usr/bin/perl
use strict;
use warnings;
use RT::Test;
use utf8;

use Test::More;

plan tests => 30;

RT::Test->set_mail_catcher;

my $queue = RT::Test->load_or_create_queue(
    name              => 'Regression',
    correspond_address => 'rt-recipient@example.com',
    comment_address    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

diag "make sure queue has no subject tag" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "set intial simple autoreply template" if $ENV{'TEST_VERBOSE'};
{
    my $template = RT::Model::Template->new( current_user => RT->system_user );
    $template->load('Autoreply');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->set_content(
        "Subject: Autreply { \$ticket->subject }\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template"
        or diag "error: $msg";
}

diag "basic test of autoreply" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new( current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => 'test',
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
}

my $str_ru_test = "\x{442}\x{435}\x{441}\x{442}";
my $str_ru_autoreply = "\x{410}\x{432}\x{442}\x{43e}\x{43e}\x{442}\x{432}\x{435}\x{442}";
my $str_ru_support = "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

diag "non-ascii Subject with ascii prefix set in the template"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_test/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "set non-ascii subject tag for the queue" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( $str_ru_support );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "ascii subject with non-ascii subject tag" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => 'test',
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_support/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "non-ascii subject with non-ascii subject tag" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_support/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$str_ru_test/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "return back the empty subject tag" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "add non-ascii subject prefix in the autoreply template" if $ENV{'TEST_VERBOSE'};
{
    my $template = RT::Model::Template->new( current_user => RT->system_user );
    $template->load('Autoreply');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->set_content(
        "Subject: $str_ru_autoreply { \$ticket->subject }\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template" or diag "error: $msg";
}

diag "ascii subject with non-ascii subject prefix in template" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => 'test',
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "non-ascii subject with non-ascii subject prefix in template"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "set non-ascii subject tag for the queue" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( $str_ru_support );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "non-ascii subject, non-ascii prefix in template and non-ascii tag"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$str_ru_autoreply/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "flush subject tag of the queue" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}


diag "don't change subject via template" if $ENV{'TEST_VERBOSE'};
{
    my $template = RT::Model::Template->new( current_user => RT->system_user );
    $template->load('Autoreply');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->set_content(
        "\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template" or diag "error: $msg";
}

diag "non-ascii Subject without changes in template" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_test/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "set non-ascii subject tag for the queue" if $ENV{'TEST_VERBOSE'};
{
    my ($status, $msg) = $queue->set_subject_tag( $str_ru_support );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "non-ascii Subject without changes in template and with non-ascii subject tag"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->create(
        queue => $queue->id,
        subject => $str_ru_test,
        requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode_utf8( $entity->head->get('Subject') );
        $subject =~ /$str_ru_test/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$str_ru_support/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

sub parse_mail {
    my $mail = shift;
    require RT::EmailParser;
    my $parser = new RT::EmailParser;
    $parser->parse_mime_entity_from_scalar( $mail );
    return $parser->entity;
}

