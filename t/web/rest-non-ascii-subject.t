# Test ticket creation with REST using non ascii subject
use strict;
use warnings;
use RT::Test tests => 9;

my $subject = Encode::decode('latin1', "Sujet accentu\x{e9}");
my $text = Encode::decode('latin1', "Contenu accentu\x{e9}");

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
    content => Encode::encode( "UTF-8", $content),
], Content_Type => 'form-data' );

my ($id) = $m->content =~ /Ticket (\d+) created/;
ok($id, "got ticket #$id");

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, $subject, "ticket subject successfully set");

my $attach = $ticket->Transactions->First->Attachments->First;
is($attach->Subject, $subject, "attachement subject successfully set");
is($attach->GetHeader('Subject'), $subject, "attachement header subject successfully set");
