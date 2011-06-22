
use strict;
use warnings;

use RT::Test tests => 20;

RT->Config->Set( FullTextSearch => Enable => 1, Indexed => 0 );

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

sub run_tests {
    my @test = @_;
    while ( my ($query, $checks) = splice @test, 0, 2 ) {
        run_test( $query, %$checks );
    }
}

my @tickets;
sub run_test {
    my ($query, %checks) = @_;
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL( "( $query_prefix ) AND ( $query )" );

    my $error = 0;

    my $count = 0;
    $count++ foreach grep $_, values %checks;
    is($tix->Count, $count, "found correct number of ticket(s) by '$query'") or $error = 1;

    my $good_tickets = ($tix->Count == $count);
    while ( my $ticket = $tix->Next ) {
        next if $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}

@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'book', Content => 'book' },
    { Subject => 'bar', Content => 'bar' },
    { Subject => 'no content', Content => undef },
);

run_tests(
    "Content LIKE 'book'" => { book => 1, bar => 0 },
    "Content LIKE 'bar'" => { book => 0, bar => 1  },
    "(Content LIKE 'baz' OR Subject LIKE 'con')" => { 'no content' => 1 },
    "(Content LIKE 'bar' OR Subject LIKE 'con')" => { 'no content' => 1, bar => 1 },
    "(Content LIKE 'bar' OR Subject LIKE 'missing')" => { bar => 1 },
);


