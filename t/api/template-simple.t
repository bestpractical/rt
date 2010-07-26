use strict;
use warnings;
use RT;
use RT::Test tests => 107;

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->Create(
    Subject   => "template testing",
    Queue     => "General",
    Requestor => ["dom\@example.com"],
);
ok($id, "Created ticket");


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

TemplateTest(
    Content      => "\ntest { \$Nonexistent }",
    FullOutput   => "test ",
    SimpleOutput => "test { \$Nonexistent }",
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
    FullOutput   => "test Nobody",
    SimpleOutput => "test { \$Ticket->OwnerObj->Name }",
);

is($ticket->Status, 'new', "test setup");
TemplateTest(
    Content      => "\ntest { \$Ticket->Resolve }",
    SkipFull     => 1,
    SimpleOutput => "test { \$Ticket->Resolve }",
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
        TransactionObj => $ticket->Transactions->First,
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

1;

