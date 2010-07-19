use strict;
use warnings;
use RT;
use RT::Test tests => 5;

my $t = RT::Template->new($RT::SystemUser);
$t->Create(
    Name => "Foo",
    Content => "\ntest",
);
ok($t->id, "Created template");
is($t->Name, "Foo");
is($t->Content, "\ntest");

my ($ok, $msg) = $t->Parse;
ok($ok, $msg);
is($t->MIMEObj->stringify_body, "test");

1;

