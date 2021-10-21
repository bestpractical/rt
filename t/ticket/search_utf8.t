use strict;
use warnings;

use RT::Test tests => undef;

use utf8;
my @tickets = (
    'ñèñ',         # accent
    '你好',         # chinese
    "\x{20779}",    # 4 bytes han
    "\x{1F36A}",    # cookie
    "\x{1F4A9}",    # pile of poo
    "\x{1F32E}",    # taco
    "\x{1F336}",    # pepper
);

RT::Test->load_or_create_custom_field(
    Name  => 'foo',
    Type  => 'Freeform',
    Queue => 'General',
);

for my $str (@tickets) {
    RT::Test->create_ticket(
        Queue        => 'General',
        Subject      => "Help: $str",
        Content      => "Content is $str",
        CustomFields => { foo => $str },
    );
}

SKIP: for my $str (@tickets) {
    skip "MySQL's 4-byte char search is inaccurate", 20
        if length $str == 1 && RT->Config->Get('DatabaseType') eq 'mysql';
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->FromSQL("Subject LIKE '$str'");
    diag "Search $str in subject";
    is( $tickets->Count, 1, 'Found 1 ticket' );
    like( $tickets->First->Subject, qr/$str/, 'Found the ticket' );

    diag "Search $str in custom field";
    $tickets->FromSQL("CustomField.foo = '$str'");
    is( $tickets->Count,                               1,    'Found 1 ticket' );
    is( $tickets->First->FirstCustomFieldValue('foo'), $str, 'Found the ticket' );
}

done_testing;
