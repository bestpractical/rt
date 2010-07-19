use strict;
use warnings;
use RT;
use RT::Test tests => 37;

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->Create(
    Subject   => "template testing",
    Queue     => "General",
    Requestor => ["dom\@example.com"],
);
ok($id, "Created ticket");

TemplateTest(
    Type    => "Full",
    Content => "\ntest",
    Output  => "test",
);

TemplateTest(
    Type    => "Full",
    Content => "\ntest { 5 * 5 }",
    Output  => "test 25",
);

TemplateTest(
    Type    => "Full",
    Content => "\ntest { \$Requestor }",
    Output  => "test dom\@example.com",
);

TemplateTest(
    Type    => "Simple",
    Content => "\ntest",
    Output  => "test",
);

TemplateTest(
    Type    => "Simple",
    Content => "\ntest { 5 * 5 }",
    Output  => "test { 5 * 5 }",
);

TemplateTest(
    Type    => "Simple",
    Content => "\ntest { \$Requestor }",
    Output  => "test dom\@example.com",
);

my $counter = 0;
sub TemplateTest {
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

    ok($t->id, "Created template");
    is($t->Name, $args{Name}, "template name");
    is($t->Content, $args{Content}, "content");
    is($t->Type, $args{Type}, "template type");

    my ($ok, $msg) = $t->Parse(
        TicketObj      => $ticket,
        TransactionObj => $ticket->Transactions->First,
    );
    ok($ok, $msg);
    is($t->MIMEObj->stringify_body, $args{Output}, "template's output");
}

1;

