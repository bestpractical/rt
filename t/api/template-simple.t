use strict;
use warnings;
use RT;
use RT::Test tests => 199;

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Load("General");

my $ticket_cf = RT::CustomField->new(RT->SystemUser);
$ticket_cf->Create(
    Name        => 'Department',
    Queue       => '0',
    Type        => 'FreeformSingle',
);

my $txn_cf = RT::CustomField->new(RT->SystemUser);
$txn_cf->Create(
    Name        => 'Category',
    LookupType  => RT::Transaction->CustomFieldLookupType,
    Type        => 'FreeformSingle',
);
$txn_cf->AddToObject($queue);

my $ticket = RT::Ticket->new(RT->SystemUser);
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
    PerlOutput   => "test",
    SimpleOutput => "test",
);

TemplateTest(
    Content      => "\ntest { 5 * 5 }",
    PerlOutput   => "test 25",
    SimpleOutput => "test { 5 * 5 }",
);

TemplateTest(
    Content      => "\ntest { \$Requestor }",
    PerlOutput   => "test dom\@example.com",
    SimpleOutput => "test dom\@example.com",
);

TemplateTest(
    Content      => "\ntest { \$TicketSubject }",
    PerlOutput   => "test ",
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
    PerlOutput   => undef,
    PerlWarnings => qr/RT::Ticket::Nonexistent Unimplemented/,
    SimpleOutput => "test { \$Ticket->Nonexistent }",
);

TemplateTest(
    Content      => "\ntest { \$Nonexistent->Nonexistent }",
    PerlOutput   => undef,
    PerlWarnings => qr/Can't call method "Nonexistent" on an undefined value/,
    SimpleOutput => "test { \$Nonexistent->Nonexistent }",
);

TemplateTest(
    Content      => "\ntest { \$Ticket->OwnerObj->Name }",
    PerlOutput   => "test root",
    SimpleOutput => "test { \$Ticket->OwnerObj->Name }",
);

TemplateTest(
    Content      => "\ntest { *!( }",
    PerlOutput   => undef,
    PerlWarnings => qr/syntax error/,
    SimpleOutput => "test { *!( }",
);

TemplateTest(
    Content      => "\ntest { \$rtname ",
    PerlOutput   => undef,
    SimpleOutput => undef,
);

is($ticket->Status, 'new', "test setup");
SimpleTemplateTest(
    Content => "\ntest { \$Ticket->Resolve }",
    Output  => "test { \$Ticket->Resolve }",
);
is($ticket->Status, 'new', "simple templates can't call ->Resolve");

# Make sure changing the template's type works
my $template = RT::Template->new(RT->SystemUser);
$template->Create(
    Name    => "type chameleon",
    Type    => "Perl",
    Content => "\ntest { 10 * 7 }",
);
ok($id = $template->id, "Created template");
$template->Parse;
is($template->MIMEObj->stringify_body, "test 70", "Perl output");

$template = RT::Template->new(RT->SystemUser);
$template->Load($id);
is($template->Name, "type chameleon");

$template->SetType('Simple');
$template->Parse;
is($template->MIMEObj->stringify_body, "test { 10 * 7 }", "Simple output");

$template = RT::Template->new(RT->SystemUser);
$template->Load($id);
is($template->Name, "type chameleon");

$template->SetType('Perl');
$template->Parse;
is($template->MIMEObj->stringify_body, "test 70", "Perl output");

undef $ticket;

my $counter = 0;
sub IndividualTemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %args = (
        Name => "Test-" . ++$counter,
        Type => "Perl",
        @_,
    );

    my $warnings;
    local $SIG{__WARN__} = sub {
        $warnings .= "@_";
    } if $args{Warnings};

    my $t = RT::Template->new(RT->SystemUser);
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
        ok(!$ok, "expected a failure");
    }

    if ($args{Warnings}) {
        like($warnings, $args{Warnings}, "warnings matched");
    }
}

sub TemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %args = @_;

    for my $type ('Perl', 'Simple') {
        next if $args{"Skip$type"};

        IndividualTemplateTest(
            %args,
            Type     => $type,
            Output   => $args{$type . 'Output'},
            Warnings => $args{$type . 'Warnings'},
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

