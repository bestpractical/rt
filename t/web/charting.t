use strict;
use warnings;

use RT::Test tests => undef;

my $core_group = RT::Test->load_or_create_group('core team');

for my $n (1..7) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my $req = 'root' . ($n % 2) . '@localhost';
    my ( $ret, $msg ) = $ticket->Create(
        Subject   => "base ticket $_",
        Queue     => "General",
        Owner     => "root",
        Requestor => $req,
        AdminCc   => [ $req, $core_group->Id ],
        Starts    => '2022-12-10 00:00:00',
        Started   => '2022-12-11 00:00:00',
        MIMEObj   => MIME::Entity->build(
            From    => $req,
            To      => 'rt@localhost',
            Subject => "base ticket $_",
            Data    => "Content $_",
        ),
    );
    ok( $ret, "ticket $n created: $msg" );
}

my ($url, $m) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

# Test that defaults work
$m->get_ok( "/Search/Chart.html?Query=id>0" );
$m->content_like(qr{<th[^>]*>Status\s*</th>\s*<th[^>]*>Ticket count\s*</th>}, "Grouped by status");
$m->content_like(qr{new\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>}, "Found results in table");
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by Queue
$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Queue" );
$m->content_like(qr{<th[^>]*>Queue\s*</th>\s*<th[^>]*>Ticket count\s*</th>}, "Grouped by queue");
$m->content_like(qr{General\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>}, "Found results in table");
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by Requestor name
$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Requestor.Name" );
$m->content_like(qr{<th[^>]*>Requestor\s+Name</th>\s*<th[^>]*>Ticket count\s*</th>},
                 "Grouped by requestor");
$m->content_like(qr{root0\@localhost\s*</th>\s*<td[^>]*>\s*<a[^>]*>3</a>}, "Found results in table");
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by Requestor email
$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Requestor.EmailAddress" );
$m->content_like(qr{<th[^>]*>Requestor\s+EmailAddress</th>\s*<th[^>]*>Ticket count\s*</th>},
                 "Grouped by requestor EmailAddress");
$m->content_like(qr{root0\@localhost\s*</th>\s*<td[^>]*>\s*<a[^>]*>3</a>}, "Found results in table");
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by Requestor phone -- which is bogus, and falls back to queue

$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Requestor.Phone" );
$m->warning_like( qr{'Requestor\.Phone' is not a valid grouping for reports} );

TODO: {
    local $TODO = "UI should show that it's group by status";
    $m->content_like(qr{new\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>},
                 "Found queue results in table, as a default");
}
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by AdminCc name
$m->get_ok("/Search/Chart.html?Query=id>0&GroupBy=AdminCc.Name");
$m->content_like( qr{<th[^>]*>AdminCc\s+Name</th>\s*<th[^>]*>Ticket count\s*</th>}, "Grouped by AdminCc" );
$m->content_like( qr{Group: core team\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>},         "Found group results in table" );
$m->content_like( qr{root0\@localhost\s*</th>\s*<td[^>]*>\s*<a[^>]*>3</a>},         "Found results in table" );
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Group by AdminCc name and duration, which is calculated in perl instead of db.
$m->get_ok("/Search/Chart.html?Query=id>0&GroupBy=AdminCc.Name&GroupBy=Starts+to+Started.Default");
$m->content_like(
    qr{<th[^>]*>AdminCc\s+Name</th>\s*<th[^>]*>Starts to Started Default\s*</th>\s*<th[^>]*>Ticket count\s*</th>},
    "Grouped by AdminCc and Starts to Started" );
$m->content_like( qr{Group: core team\s*</th>\s*<th[^>]*>24 hours</th>\s*<td[^>]*>\s*<a[^>]*>7</a>},
    "Found group results in table" );
$m->content_like( qr{root0\@localhost\s*</th>\s*<td[^>]*>\s*<a[^>]*>3</a>}, "Found results in table" );
ok( $m->dom->at('div.chart.image canvas'), "Found image");

diag "Confirm subnav links use Query param before saved search in session.";

$m->get_ok( "/Search/Chart.html?Query=id>0" );
$m->follow_link_ok( { text => 'Advanced' } );
is( $m->form_name('BuildQueryAdvanced')->find_input('Query')->value,
    'id>0', 'Advanced page has Query param with id search' );

# Load the session with another search.
$m->get_ok( "/Search/Results.html?Query=Queue='General'" );

$m->get_ok( "/Search/Chart.html?Query=id>0" );
$m->follow_link_ok( { text => 'Advanced' } );
is( $m->form_name('BuildQueryAdvanced')->find_input('Query')->value,
    'id>0', 'Advanced page still has Query param with id search' );

# Test query with JOINs
$m->get_ok( "/Search/Chart.html?Query=Requestor.Name LIKE 'root'" );
$m->content_like(qr{<th[^>]*>Status\s*</th>\s*<th[^>]*>Ticket count\s*</th>}, "Grouped by status");
$m->content_like(qr{new\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>}, "Found results in table");
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Test txn charts
$m->get_ok("/Search/Chart.html?Class=RT::Transactions&Query=Type=Create");
$m->content_like( qr{<th[^>]*>Creator\s*</th>\s*<th[^>]*>Transaction count\s*</th>}, "Grouped by creator" );
$m->content_like( qr{RT_System\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>},                 "Found results in table" );
ok( $m->dom->at('div.chart.image canvas'), "Found image");

# Test asset charts
my $asset = RT::Asset->new( RT->SystemUser );
$asset->Create( Name => 'test', Catalog => 'General assets', Status => 'new' );
ok( $asset->Id, 'Created test asset' );
$m->get_ok("/Search/Chart.html?Class=RT::Assets&Query=id>0");
$m->content_like( qr{<th[^>]*>Status\s*</th>\s*<th[^>]*>Asset count\s*</th>}, "Grouped by status" );
$m->content_like( qr{new\s*</th>\s*<td[^>]*>\s*<a[^>]*>1</a>},                "Found results in table" );
ok( $m->dom->at('div.chart.image canvas'), "Found image");

done_testing;
