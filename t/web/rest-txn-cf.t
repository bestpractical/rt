use strict;
use warnings;
use RT::Interface::REST;

use RT::Test tests => 37;
use Test::Warn;

my ($baseurl, $m) = RT::Test->started_ok;

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

{
    my $cf = RT::Test->load_or_create_txn_custom_field(
        Name  => 'txn_cf',
        Type  => 'FreeformSingle',
        Queue => $queue,
    );
    ok($cf->Id, "created a CustomField: txn_cf");
}
{
    my $cf = RT::Test->load_or_create_txn_custom_field(
        Name  => 'txn_cf_multi',
        Type  => 'FreeformMultiple',
        Queue => $queue,
    );
    ok($cf->Id, "created a CustomField: txn_cf");
}

my $other_queue = RT::Test->load_or_create_queue(Name => 'Other Queue');
ok($other_queue->Id, "loaded the Other Queue queue");

{
    my $cf = RT::Test->load_or_create_txn_custom_field(
        Name  => 'txn_other_queue_cf',
        Type  => 'FreeformSingle',
        Queue => $other_queue,
    );
    ok($cf->Id, "created a CustomField");
}

$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
    format  => 'l',
]);

my $text = $m->content;
my @lines = $text =~ m{.*}g;
shift @lines; # header

ok($text =~ s/Subject:\s*$/Subject: REST interface/m, "successfully replaced subject");

$m->post("$baseurl/REST/1.0/ticket/edit", [
    user    => 'root',
    pass    => 'password',

    content => $text,
], Content_Type => 'form-data');

my ($id) = $m->content =~ /Ticket (\d+) created/;
ok($id, "got ticket #$id");

$text = join("\n", ( "Ticket: $id", "Action: correspond", "Content-Type: text/plain" ));
$m->post(
    "$baseurl/REST/1.0/ticket/$id/comment",
    [
        user => 'root',
        pass => 'password',
        content => "$text\nText: Test with no CF",
    ],
    Content_Type => 'form-data'
);
like($m->content, qr{Correspondence added}, "correspondance added - no CF");

my $with_valid_cf = $text . "\nText: Test with valid CF\nCF.{txn_cf}: valid cf";

$m->post(
    "$baseurl/REST/1.0/ticket/$id/comment",
    [
        user => 'root',
        pass => 'password',
        content => $with_valid_cf,
    ],
    Content_Type => 'form-data'
);
like($m->content, qr{Correspondence added}, "correspondance added - valid CF");
unlike($m->content, qr{Invalid custom field name}, "no invalid custom field - valid CF");

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, "REST interface", "subject successfully set");

my $txn = $ticket->Transactions->Last;
my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};
like($msg->Content, qr/Test with valid CF/, "Transaction contains expected content - valid CF");

is($txn->FirstCustomFieldValue('txn_cf'), "valid cf", "CF successfully set - valid CF");

$m->post(
    "$baseurl/REST/1.0/ticket/$id/history",
    [
        user   => 'root',
        pass   => 'password',
        format => 'l',
    ],
    Content_Type => 'form-data'
);

like($m->content, qr/CF.\{txn_cf\}: valid cf/, "Ticket history contains expected content - valid CF");

my $with_nonexistant_cf = $text . "\nText: Test with invalid CF\nCF.{other_cf}: invalid cf";

$m->post(
    "$baseurl/REST/1.0/ticket/$id/comment",
    [
        user => 'root',
        pass => 'password',
        content => $with_nonexistant_cf,
    ],
    Content_Type => 'form-data'
);
like($m->content, qr{Correspondence added}, "correspondance added - nonexistant CF");
like($m->content, qr{Invalid custom field name}, "invalid custom field - nonexistant CF");

$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, "REST interface", "subject successfully set");

$txn = $ticket->Transactions->Last;
($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};
like($msg->Content, qr/Test with invalid CF/, "Transaction contains expected content - invalid CF");

warning_like {$txn->FirstCustomFieldValue('other_cf')} qr"Couldn't load custom field by 'other_cf' identifier", "CF isn't set - invalid CF";

my $with_other_queue_cf = $text . "\nText: Test with other queue CF\nCF.{txn_other_queue_cf}: invalid cf";

$m->post(
    "$baseurl/REST/1.0/ticket/$id/comment",
    [
        user => 'root',
        pass => 'password',
        content => $with_other_queue_cf,
    ],
    Content_Type => 'form-data'
);
like($m->content, qr{Correspondence added}, "correspondance added - other queue CF");
like($m->content, qr{Invalid custom field name}, "invalid custom field - other queue CF");

$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, "REST interface", "subject successfully set");

$txn = $ticket->Transactions->Last;
($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};
like($msg->Content, qr/Test with other queue CF/, "Transaction contains expected content - other queue CF");

warning_like {$txn->FirstCustomFieldValue('txn_other_queue_cf')} qr"Couldn't load custom field by 'txn_other_queue_cf' identifier", "CF isn't set - other queue CF";

my $with_valid_cf_multi = $text . "\nText: Test with multi CF\nCF.{txn_cf_multi}: Value 1, Value 2";

$m->post(
    "$baseurl/REST/1.0/ticket/$id/comment",
    [
        user => 'root',
        pass => 'password',
        content => $with_valid_cf_multi,
    ],
    Content_Type => 'form-data'
);
like($m->content, qr{Correspondence added}, "correspondance added - valid CF multi");
unlike($m->content, qr{Invalid custom field name}, "no invalid custom field - valid CF multi");

$ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket - valid CF multi");
is($ticket->Subject, "REST interface", "subject successfully set - valid CF multi");

$txn = $ticket->Transactions->Last;
($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};
like($msg->Content, qr/Test with multi CF/, "Transaction contains expected content - valid CF multi");

is($txn->FirstCustomFieldValue('txn_cf_multi'), "Value 1", "CF successfully set - valid CF multi");

$m->post(
    "$baseurl/REST/1.0/ticket/$id/history",
    [
        user   => 'root',
        pass   => 'password',
        format => 'l',
    ],
    Content_Type => 'form-data'
);

like($m->content, qr/CF.\{txn_cf_multi\}: Value 1,Value 2/, "Ticket history contains expected content - valid CF multi");
