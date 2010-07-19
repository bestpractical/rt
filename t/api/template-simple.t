use strict;
use warnings;
use RT;
use RT::Test tests => 16;

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->Create(
    Subject   => "template testing",
    Queue     => 'General',
    Requestor => ['dom@example.com'],
);
ok($id, 'Created ticket');

# no interpolation
{
    my $t = RT::Template->new($RT::SystemUser);
    $t->Create(
        Name => "Foo",
        Content => "\ntest",
    );
    ok($t->id, "Created template");
    is($t->Name, "Foo");
    is($t->Content, "\ntest");

    my ($ok, $msg) = $t->Parse(TicketObj => $ticket);
    ok($ok, $msg);
    is($t->MIMEObj->stringify_body, "test");
}

# code interpolation
{
    my $t = RT::Template->new($RT::SystemUser);
    $t->Create(
        Name => "Foo",
        Content => "\ntest { 5 * 5 }",
    );
    ok($t->id, "Created template");
    is($t->Name, "Foo");
    is($t->Content, "\ntest { 5 * 5 }");

    my ($ok, $msg) = $t->Parse(TicketObj => $ticket);
    ok($ok, $msg);
    is($t->MIMEObj->stringify_body, "test 25");
}

# variable interpolation
{
    my $t = RT::Template->new($RT::SystemUser);
    $t->Create(
        Name => "Foo",
        Content => "\ntest { \$Requestor }",
    );
    ok($t->id, "Created template");
    is($t->Name, "Foo");
    is($t->Content, "\ntest { \$Requestor }");

    my ($ok, $msg) = $t->Parse(TicketObj => $ticket);
    ok($ok, $msg);
    is($t->MIMEObj->stringify_body, "test dom\@example.com");
}

1;

