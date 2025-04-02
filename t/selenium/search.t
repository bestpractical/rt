
use strict;
use warnings;

use RT::Test::Assets tests => undef, selenium => 1;

my ( $url, $s ) = RT::Test->started_ok;

$s->login();

RT::Test->create_tickets( { Queue => 1 }, { Subject => 'ticket foo' }, { Subject => 'ticket bar' }, );

$s->get_ok('/Search/Build.html?NewQuery=1');
$s->submit_form_ok(
    {
        form_name => 'BuildQuery',
        fields    => {
            ValueOfAttachment => 'ticket foo',
        },
        button => 'DoSearch',
    },
    'Search tickets'
);

$s->text_contains('Found 1 ticket');

create_assets( { Catalog => 1, Name => 'asset foo' }, { Catalog => 1, Name => 'asset bar' }, );

$s->get_ok('/Search/Build.html?Class=RT::Assets&NewQuery=1');
$s->submit_form_ok(
    {
        form_name => 'BuildQuery',
        fields    => {
            ValueOfAttachment => 'asset foo',
        },
        button => 'DoSearch',
    },
    'Search assets'
);
$s->text_contains('Found 1 asset');

$s->get_ok('/Search/Build.html?Class=RT::Transactions;ObjectType=RT::Ticket;NewQuery=1');
$s->submit_form_ok(
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

$s->text_contains('Found 1 transaction');

$s->logout;

done_testing;
