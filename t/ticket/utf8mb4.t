use strict;
use warnings;

use utf8;

use RT::Test nodata => 1, tests => undef;

my %tickets = (
    'ascii'  => '#',
    'accent' => 'ñèñ',
    ck       => "\x{1F36A}",
    kanji    => "\x{20779}",
    pop      => "\x{1F4A9}",
    taco     => "\x{1F32E}",
    pepper   => "\x{1F336}",
);

# setup the queue

my $queue = 'General';                                          # used globaly
my $q     = RT::Test->load_or_create_queue( Name => $queue );
ok( $q->id, "Loaded the queue" );

my %cf = (
    desc => create_cf( $q, 'desc' ),
    char => create_cf( $q, 'char' ),
    cat  => create_cf( $q, 'cat' )
);
my %cats = ( regular => 0, emoji => 0 );

while ( my ( $desc, $char ) = each %tickets ) {

    my $cat = ord($char) > 100000 ? 'emoji' : 'regular';
    $cats{$cat}++;

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ( $id, undef, $msg ) = $ticket->Create(
        Queue     => $q->id,
        Requestor => ['test@example.com'],
        Subject   => subject( $desc, $char ),
        Content   => "Content is $char$char, still $desc",
        $cf{desc}->{create} => $desc,    # a unique text description
        $cf{char}->{create} => $char,    # 1, possibly 4-byte, character
        $cf{cat}->{create}  => $cat,     # category (emoji/regular)
    );
    ok( $id, $msg );
}

my $tix = RT::Tickets->new( RT->SystemUser );
$tix->FromSQL("Queue = '$queue'");
is( $tix->Count, scalar( keys %tickets ), "found all the tickets" )
    or diag "wrong results from SQL:\n" . $tix->BuildSelectCountQuery;

while ( my ( $cat, $nb ) = each %cats ) {
    my $tix_cat = RT::Tickets->new( RT->SystemUser );
    $tix_cat->FromSQL("Queue = '$queue' AND $cf{cat}->{search} = '$cat'");
    is( $tix_cat->Count, $nb, "found $nb $cat ticket (from cat CF)" )
        or diag "wrong results from SQL:\n" . $tix_cat->BuildSelectCountQuery;
}

while ( my ( $desc, $char ) = each %tickets ) {
    my $subject = subject( $desc, $char );
    test_search( $desc, $char, 'Subject',           $char );
    test_search( $desc, $char, $cf{desc}->{search}, $desc );
    test_search( $desc, $char, $cf{char}->{search}, $char );
}

done_testing;

sub subject {
    my ( $desc, $char ) = @_;
    return "$char ($desc)";
}

sub create_cf {
    my ( $q, $name ) = @_;
    my $cf = RT::Test->load_or_create_custom_field(
        Name      => $name,
        Type      => 'Freeform',
        MaxValues => 0,
        Queue     => $q->id
    );
    ok( $cf->id, "Created the $name CF" );
    my $create = "CustomField-" . $cf->id;    # key used to create the CF
    my $search = "CF.$name";                  # field in search
    return { name => $name, create => $create, search => $search };
}

sub test_search {
    my ( $desc, $char, $field, $to_search ) = @_;

    my $tix = RT::Tickets->new( RT->SystemUser );
    $tix->FromSQL("Queue = '$queue' AND $field LIKE '$to_search'");

    is( $tix->Count, 1, "found $to_search ticket (from $field)" )
        or diag "wrong results from SQL:\n" . $tix->BuildSelectCountQuery;

    my $ticket = $tix->First;
    return if !$ticket;
    is( $ticket->Subject,
        subject( $desc, $char ),
        "$char, $field: Subject is right"
      );
}
