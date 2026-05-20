
use strict;
use warnings;

use RT::Test::Assets tests => undef, playwright => 1;
use utf8;

my ( $url, $p ) = RT::Test->started_ok;

$p->login();

RT::Test->create_tickets(
    { Queue   => 1 },
    { Subject => 'ticket foo' },
    { Subject => 'ticket bar' },
    { Subject => 'ticket 测试' },
);

$p->get_ok('/Search/Build.html?NewQuery=1');
$p->submit_form_ok(
    {
        form_name => 'BuildQuery',
        fields    => {
            ValueOfAttachment => 'ticket foo',
        },
        button => 'DoSearch',
    },
    'Search tickets'
);

$p->text_contains('Found 1 ticket');

create_assets( { Catalog => 1, Name => 'asset foo' }, { Catalog => 1, Name => 'asset bar' }, );

$p->get_ok('/Search/Build.html?Class=RT::Assets&NewQuery=1');
$p->submit_form_ok(
    {
        form_name => 'BuildQuery',
        fields    => {
            ValueOfAttachment => 'asset foo',
        },
        button => 'DoSearch',
    },
    'Search assets'
);
$p->text_contains('Found 1 asset');

$p->get_ok('/Search/Build.html?Class=RT::Transactions;ObjectType=RT::Ticket;NewQuery=1');
$p->submit_form_ok(
    {
        form_name => 'BuildQuery',
        fields    => {
            ValueOfType          => 'Create',
            ValueOfTicketSubject => 'ticket foo',
        },
        button => 'DoSearch',
    },
    'Search transactions'
);

$p->text_contains('Found 1 transaction');

my $search = "测试";
$p->get_ok( URI->new('/Search/Simple.html') );
$p->submit_form_ok(
    {   form   => '#SimpleSearchForm form',
        fields => { q => $search, },
    },
    'Simple search'
);

$p->title_is( 'Found 1 ticket', 'Found 1 ticket' );
$p->text_contains( "ticket $search", "Found test ticket with $search" );

$p->logout;

done_testing;
