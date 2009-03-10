#!/usr/bin/env perl
# Test ticket creation with REST using non ascii subject
use strict;
use warnings;
use Test::More tests => 7;
use RT::Test;

my $subject = "Sujet accentu\x{00e9}";
my $text = "Contenu accentu\x{00e9}";

my ($baseurl, $m) = RT::Test->started_ok;

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

my $content = "id: ticket/new
Queue: General
Requestor: root
Subject: $subject
Cc:
AdminCc:
Owner:
Status: new
Priority:
InitialPriority:
FinalPriority:
TimeEstimated:
Starts: 2009-03-10 16:14:55
Due: 2009-03-10 16:14:55
Text: $text";


$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
    content => $content,
], Content_Type => 'form-data' );

my ($id) = $m->content =~ /Ticket (\d+) created/;
ok($id, "got ticket #$id");

my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, $subject, "ticket subject successfully set");
is($ticket->Transactions->First->Attachments->First->Subject, $subject, "attachement subject successfully set");
is($ticket->Transactions->First->Attachments->First->GetHeader('Subject'), $subject, "attachement header subject successfully set");

