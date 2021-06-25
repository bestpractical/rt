use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_tickets(
    {   Queue   => 'General',
        Subject => 'Requestor order test',
        Content => 'test',
    },
    { Requestor => 'alice@localhost', },
    { Requestor => 'richard@localhost', },
    { Requestor => 'bob@localhost', },
);

ok $m->login, 'logged in';

$m->get_ok('/Search/Results.html?Query=id>0');
$m->follow_link_ok( { text => 'Requestor' } );
$m->text_like( qr/alice.*bob.*richard/i, 'Order by Requestors ASC' );
$m->follow_link_ok( { text => 'Requestor' } );
$m->text_like( qr/richard.*bob.*alice/i, , 'Order by Requestors DESC' );

done_testing;
