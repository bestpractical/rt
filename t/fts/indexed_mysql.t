
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'Not mysql' unless RT->Config->Get('DatabaseType') eq 'mysql';

RT->Config->Set( FullTextSearch => Enable => 1, Indexed => 1, Table => 'AttachmentsIndex' );

setup_indexing();

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

sub setup_indexing {
    my %args = (
        'no-ask'       => 1,
        command        => $RT::SbinPath .'/rt-setup-fulltext-index',
        dba            => $ENV{'RT_DBA_USER'},
        'dba-password' => $ENV{'RT_DBA_PASSWORD'},
    );
    my ($exit_code, $output) = RT::Test->run_and_capture( %args );
    ok(!$exit_code, "setted up index") or diag "output: $output";
}

sub sync_index {
    my %args = (
        command => $RT::SbinPath .'/rt-fulltext-indexer',
    );
    my ($exit_code, $output) = RT::Test->run_and_capture( %args );
    ok(!$exit_code, "setted up index") or diag "output: $output";
}

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

    # Assumes we are called by run_tests() only
    local $Test::Builder::Level = $Test::Builder::Level + 2;

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
    { Subject => 'first', Content => 'english' },
    { Subject => 'second',  Content => 'french' },
    { Subject => 'third',  Content => 'spanish' },
    { Subject => 'fourth',  Content => 'german' },
);
sync_index();

run_tests(
    "Content LIKE 'english'" => { first => 1, second => 0, third => 0, fourth => 0 },
    "Content LIKE 'french'" => { first => 0, second => 1, third => 0, fourth => 0 },
);

# Check fulltext results for merged tickets
# note: merge code itself is tested by ticket/merge.t
{
    $q = RT::Test->load_or_create_queue( Name => 'Mergers' );
    ok ($q && $q->id, 'loaded or created queue Mergers');

    # Create two tickets for merging, overwriting the @tickets used before to
    # limit the subsequent search to just these ones
    @tickets = RT::Test->create_tickets(
        { Queue => $q->id },
        { Subject => 'MergeSource1',     Content => 'pirates' },
        { Subject => 'MergeSource2',     Content => 'ninjas'  },
        { Subject => 'MergeDestination', Content => 'robots'  },
    );

    sync_index();

    # Make sure we can see tickets as expected before the merge happens
    run_tests(
        "Content LIKE 'pirates'" => { MergeSource1 => 1, MergeSource2 => 0, MergeDestination => 0 },
        "Content LIKE 'ninjas'"  => { MergeSource1 => 0, MergeSource2 => 1, MergeDestination => 0 },
        "Content LIKE 'robots'"  => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
    );

    my $source1 = $tickets[0];
    my $source2 = $tickets[1];
    my $destination = $tickets[2];

    # Sanity check the array indices mean what we think
    ok ($source1->Subject eq 'MergeSource1', 'Subject of tickets[0] should be MergeSource1');
    ok ($source2->Subject eq 'MergeSource2', 'Subject of tickets[1] should be MergeSource2');
    ok ($destination->Subject eq 'MergeDestination', 'Subject of tickets[2] should be MergeDestination');

    # First merge
    my ($id,$m) = $source1->MergeInto( $destination->id );
    ok ($id,$m);

    sync_index();

    run_tests(
        "Content LIKE 'pirates'" => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
        "Content LIKE 'ninjas'"  => { MergeSource1 => 0, MergeSource2 => 1, MergeDestination => 0 },
        "Content LIKE 'robots'"  => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
    );

    # Second merge
    ($id,$m) = $source2->MergeInto( $destination->id );
    ok ($id,$m);

    sync_index();

    run_tests(
        "Content LIKE 'pirates'" => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
        "Content LIKE 'ninjas'"  => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
        "Content LIKE 'robots'"  => { MergeSource1 => 0, MergeSource2 => 0, MergeDestination => 1 },
    );
}

@tickets = ();

done_testing;
