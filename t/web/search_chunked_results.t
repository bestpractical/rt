use strict;
use warnings;

use URI::Escape qw(uri_escape);
use XML::Simple;
use Data::ICal;
use RT::Test tests => undef;

# The default unpaginated chunk size is 100 in CollectionList, TSVExport,
# ResultsRSSView, and iCal/dhandler. Create 105 tickets to cross the
# chunk boundary. Results beyond the first 100 can only appear if NextPage
# was called to fetch the second chunk.
my $ticket_count = 105;

my $queue = RT::Test->load_or_create_queue( Name => 'ChunkTest' );
ok $queue && $queue->id, 'created ChunkTest queue';

my $due_obj = RT::Date->new( RT->SystemUser );
$due_obj->SetToNow;
$due_obj->AddDays(7);

{
    # Disable scrips during bulk ticket creation to speed up the test
    my $orig_new_txn = RT::Record->can('_NewTransaction');
    no warnings 'redefine';
    local *RT::Record::_NewTransaction = sub {
        my $self = shift;
        return $self->$orig_new_txn( @_, ActivateScrips => 0 );
    };
    RT::Test->create_tickets(
        { Queue => 'ChunkTest', Due => $due_obj->ISO },
        map { { Subject => "Chunk test ticket $_" } } 1 .. $ticket_count,
    );
}

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login(), 'logged in as root';

my $query       = "Queue = 'ChunkTest'";
my $query_enc   = uri_escape($query);
my $results_url = "/Search/Results.html?Query=$query_enc&RowsPerPage=0";

diag 'Unpaginated web search returns results beyond the first 100-row chunk';
{
    $m->get_ok($results_url);
    for my $i ( 1 .. $ticket_count ) {
        $m->text_contains( "Chunk test ticket $i", "ticket $i appears in unpaginated web results", );
    }
}

diag 'TSV export returns all results across chunks';
{
    my $format = uri_escape("'__id__','__Subject__'");
    $m->get_ok("/Search/Results.tsv?Query=$query_enc&Format=$format");
    my @lines = grep {/\S/} split /\r?\n/, $m->content;

    # One header line + $ticket_count data lines
    is scalar(@lines), $ticket_count + 1, "TSV export contains all $ticket_count tickets";
}

diag 'RSS feed returns all results across chunks';
{
    $m->get_ok($results_url);
    $m->follow_link_ok( { text => 'RSS' } );
    is $m->content_type, 'application/rss+xml', 'content type is RSS';
    my $rss = XML::Simple::XMLin( $m->content );
    is scalar( @{ $rss->{item} } ), $ticket_count, "RSS feed contains all $ticket_count tickets";
}

diag 'iCal feed returns all results across chunks';
{
    $m->get_ok($results_url);
    $m->follow_link_ok( { text => 'iCal' } );
    is $m->content_type, 'text/calendar', 'content type is text/calendar';
    my $ical    = Data::ICal->new( data => $m->content );
    my @entries = $ical->entries;

    # Each ticket generates two VEVENT entries (Start and Due)
    is scalar( @{ $entries[0] } ), $ticket_count * 2, "iCal feed contains all $ticket_count tickets (2 entries each)";
}

done_testing;
