use strict;
use warnings;

use RT::Test tests => undef;

plan skip_all => 'GD required'
    unless GD->require;

for my $n (1..7) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my $req = 'root' . ($n % 2) . '@localhost';
    my ( $ret, $msg ) = $ticket->Create(
        Subject   => "base ticket $_",
        Queue     => "General",
        Owner     => "root",
        Requestor => $req,
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
$m->content_like(qr{<img src="/Search/Chart\?}, "Found image");

$m->get_ok( "/Search/Chart?Query=id>0" );
is( $m->content_type, "image/png" );
ok( length($m->content), "Has content" );


# Group by Queue
$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Queue" );
$m->content_like(qr{<th[^>]*>Queue\s*</th>\s*<th[^>]*>Ticket count\s*</th>}, "Grouped by queue");
$m->content_like(qr{General\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>}, "Found results in table");
$m->content_like(qr{<img src="/Search/Chart\?}, "Found image");

$m->get_ok( "/Search/Chart?Query=id>0&GroupBy=Queue" );
is( $m->content_type, "image/png" );
ok( length($m->content), "Has content" );


# Group by Requestor email
$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Requestor.EmailAddress" );
$m->content_like(qr{<th[^>]*>Requestor\s+EmailAddress</th>\s*<th[^>]*>Ticket count\s*</th>},
                 "Grouped by requestor");
$m->content_like(qr{root0\@localhost\s*</th>\s*<td[^>]*>\s*<a[^>]*>3</a>}, "Found results in table");
$m->content_like(qr{<img src="/Search/Chart\?}, "Found image");

$m->get_ok( "/Search/Chart?Query=id>0&GroupBy=Requestor.EmailAddress" );
is( $m->content_type, "image/png" );
ok( length($m->content), "Has content" );

# Group by Requestor phone -- which is bogus, and falls back to queue

$m->get_ok( "/Search/Chart.html?Query=id>0&GroupBy=Requestor.Phone" );
$m->warning_like( qr{'Requestor\.Phone' is not a valid grouping for reports} );

TODO: {
    local $TODO = "UI should show that it's group by status";
    $m->content_like(qr{new\s*</th>\s*<td[^>]*>\s*<a[^>]*>7</a>},
                 "Found queue results in table, as a default");
}
$m->content_like(qr{<img src="/Search/Chart\?}, "Found image");

$m->get_ok( "/Search/Chart?Query=id>0&GroupBy=Requestor.Phone" );
$m->warning_like( qr{'Requestor\.Phone' is not a valid grouping for reports} );
is( $m->content_type, "image/png" );
ok( length($m->content), "Has content" );

diag "Confirm subnav links use Query param before saved search in session.";

$m->get_ok( "/Search/Chart.html?Query=id>0" );
my $advanced = $m->find_link( text => 'Advanced' )->URI->equery;
like( $advanced, qr{Query=id%3E0},
      'Advanced link has Query param with id search'
    );

# Load the session with another search.
$m->get_ok( "/Search/Results.html?Query=Queue='General'" );

$m->get_ok( "/Search/Chart.html?Query=id>0" );
$advanced = $m->find_link( text => 'Advanced' )->URI->equery;
like( $advanced, qr{Query=id%3E0},
      'Advanced link still has Query param with id search'
    );

done_testing;
