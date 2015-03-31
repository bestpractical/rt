use strict;
use warnings;

use RT::Test tests => undef;

my $cf;
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg)=  $cf->Create(
        Name => 'Status',
        Queue => '0',
        Description => 'A Testing custom field',
        Type=> 'FreeformSingle'
    );
    ok($id, 'Global custom field correctly created');

    ($id, $msg)=  $cf->Create(
        Name => 'Subject',
        Queue => '0',
        Description => 'A Testing custom field',
        Type => 'FreeformSingle'
    );
    ok($id, 'Global custom field correctly created');
}

my $queuea = RT::Test->load_or_create_queue( Name => 'A' );
ok $queuea && $queuea->id;

my $queueb = RT::Test->load_or_create_queue( Name => 'B' );
ok $queueb && $queueb->id;

my $template;
{
    my $content = <<'END';
===Create-Ticket: approval
Subject: New ticket
Queue: B
Status: open
END
    $template = RT::Template->new(RT->SystemUser);
    my ($status, $msg) = $template->Create(
        Name => "Test",
        Queue => $queuea->id,
        Content => $content,
    );
    ok $status, "created a template";

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($status, $msg) = $scrip->Create(
        Queue => 'A',
        ScripCondition => 'On Create',
        ScripAction => 'Create Tickets',
        Template => $template->Name,
    );
    ok $status, "created a scrip";
}

{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id) = $ticket->Create( Queue => $queuea, Subject => 'test' );
    ok $id, "created a ticket";

    my $last = RT::Test->last_ticket;
    isnt $last->id, $id;
    is $last->FirstCustomFieldValue('Status'), undef;
    is $last->Status, 'open';

    is $last->FirstCustomFieldValue('Subject'), undef;
    is $last->Subject, 'New ticket';
}

done_testing;
