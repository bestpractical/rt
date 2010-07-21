use strict;
use warnings;
use RT;
use RT::Test tests => 48;

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
    Content      => "\ntest { \$Ticket->Nonexistent }",
    FullOutput   => undef,
    SimpleOutput => "test { \$Ticket->Nonexistent }",
);

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

    ok($t->id, "Created template");
    is($t->Name, $args{Name}, "template name");
    is($t->Content, $args{Content}, "content");
    is($t->Type, $args{Type}, "template type");

    my ($ok, $msg) = $t->Parse(
        TicketObj      => $ticket,
        TransactionObj => $ticket->Transactions->First,
    );
    if (defined $args{Output}) {
        ok($ok, $msg);
        is($t->MIMEObj->stringify_body, $args{Output}, "template's output");
    }
    else {
        ok(!$ok, "expected failure: $msg");
    }
}

sub TemplateTest {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %args = @_;

    for my $type ('Full', 'Simple') {
        IndividualTemplateTest(
            %args,
            Type   => $type,
            Output => $args{$type . 'Output'},
        );
    }
}

1;

