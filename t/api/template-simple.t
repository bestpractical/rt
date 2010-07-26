use strict;
use warnings;
use RT;
use RT::Test tests => 186;

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Load("General");

my $ticket_cf = RT::CustomField->new($RT::SystemUser);
$ticket_cf->Create(
    Name        => 'Department',
    Queue       => '0',
    Type        => 'FreeformSingle',
);

my $txn_cf = RT::CustomField->new($RT::SystemUser);
$txn_cf->Create(
    Name        => 'Category',
    LookupType  => RT::Transaction->CustomFieldLookupType,
    Type        => 'FreeformSingle',
);
$txn_cf->AddToObject($queue);

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->Create(
    Subject   => "template testing",
    Queue     => "General",
    Owner     => 'root@localhost',
    Requestor => ["dom\@example.com"],
    "CustomField-" . $txn_cf->id => "Special",
);
ok($id, "Created ticket: $msg");
my $txn = $ticket->Transactions->First;

$ticket->AddCustomFieldValue(
    Field => 'Department',
    Value => 'Coolio',
);

TemplateTest(
    Content      => "\ntest",
    FullOutput   => "test",
    SimpleOutput => "test",
);

TemplateTest(
    Content      => "\ntest { 5 * 5 }",
    FullOutput   => "test 25",
    SimpleOutput => "test { 5 * 5 }",
);

TemplateTest(
    Content      => "\ntest { \$Requestor }",
    FullOutput   => "test dom\@example.com",
    SimpleOutput => "test dom\@example.com",
);

TemplateTest(
    Content      => "\ntest { \$TicketSubject }",
    FullOutput   => "test ",
    SimpleOutput => "test template testing",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketQueueId }",
    Output  => "test 1",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketQueueName }",
    Output  => "test General",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketOwnerId }",
    Output  => "test 12",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketOwnerName }",
    Output  => "test root",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketOwnerEmailAddress }",
    Output  => "test root\@localhost",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketStatus }",
    Output  => "test new",
);

SimpleTemplateTest(
    Content => "\ntest #{ \$TicketId }",
    Output  => "test #" . $ticket->id,
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketCFDepartment }",
    Output  => "test Coolio",
);

SimpleTemplateTest(
    Content => "\ntest #{ \$TransactionId }",
    Output  => "test #" . $txn->id,
);

SimpleTemplateTest(
    Content => "\ntest { \$TransactionType }",
    Output  => "test Create",
);

SimpleTemplateTest(
    Content => "\ntest { \$TransactionCFCategory }",
    Output  => "test Special",
);

SimpleTemplateTest(
    Content => "\ntest { \$TicketDelete }",
    Output  => "test { \$TicketDelete }",
);

SimpleTemplateTest(
    Content => "\ntest { \$Nonexistent }",
    Output  => "test { \$Nonexistent }",
);

TemplateTest(
    Content      => "\ntest { \$Ticket->Nonexistent }",
    FullOutput   => undef,
    SimpleOutput => "test { \$Ticket->Nonexistent }",
);

TemplateTest(
    Content      => "\ntest { \$Nonexistent->Nonexistent }",
    FullOutput   => undef,
    SimpleOutput => "test { \$Nonexistent->Nonexistent }",
);

TemplateTest(
    Content      => "\ntest { \$Ticket->OwnerObj->Name }",
    FullOutput   => "test root",
    SimpleOutput => "test { \$Ticket->OwnerObj->Name }",
);

TemplateTest(
    Content      => "\ntest { *!( }",
    FullOutput   => undef,
    SimpleOutput => "test { *!( }",
);

is($ticket->Status, 'new', "test setup");
SimpleTemplateTest(
    Content => "\ntest { \$Ticket->Resolve }",
    Output  => "test { \$Ticket->Resolve }",
);
is($ticket->Status, 'new', "simple templates can't call ->Resolve");

# Make sure changing the template's type works
my $template = RT::Template->new($RT::SystemUser);
$template->Create(
    Name    => "type chameleon",
    Type    => "Full",
    Content => "\ntest { 10 * 7 }",
);
ok($id = $template->id, "Created template");
$template->Parse;
is($template->MIMEObj->stringify_body, "test 70", "Full output");

$template = RT::Template->new($RT::SystemUser);
$template->Load($id);
is($template->Name, "type chameleon");

$template->SetType('Simple');
$template->Parse;
is($template->MIMEObj->stringify_body, "test { 10 * 7 }", "Simple output");

$template = RT::Template->new($RT::SystemUser);
$template->Load($id);
is($template->Name, "type chameleon");

$template->SetType('Full');
$template->Parse;
is($template->MIMEObj->stringify_body, "test 70", "Full output");

my $counter = 0;
sub IndividualTemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %args = (
        Name => "Test-" . ++$counter,
        Type => "Full",
        @_,
    );

    my $t = RT::Template->new($RT::SystemUser);
    $t->Create(
        Name    => $args{Name},
        Type    => $args{Type},
        Content => $args{Content},
    );

    ok($t->id, "Created $args{Type} template");
    is($t->Name, $args{Name}, "$args{Type} template name");
    is($t->Content, $args{Content}, "$args{Type} content");
    is($t->Type, $args{Type}, "template type");

    my ($ok, $msg) = $t->Parse(
        TicketObj      => $ticket,
        TransactionObj => $txn,
    );
    if (defined $args{Output}) {
        ok($ok, $msg);
        is($t->MIMEObj->stringify_body, $args{Output}, "$args{Type} template's output");
    }
    else {
        ok(!$ok, "expected failure: $msg");
    }
}

sub TemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %args = @_;

    for my $type ('Full', 'Simple') {
        next if $args{"Skip$type"};

        IndividualTemplateTest(
            %args,
            Type   => $type,
            Output => $args{$type . 'Output'},
        );
    }
}

sub SimpleTemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %args = @_;

    IndividualTemplateTest(
        %args,
        Type => 'Simple',
    );
}

1;

