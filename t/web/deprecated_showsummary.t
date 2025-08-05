use strict;
use warnings;

# Use the Deprecated test plugin to provide a test page that can call the deprecated ShowSummary template
use RT::Test tests => undef, plugins => ["Deprecated"];

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Create a test ticket
my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Test ticket for ShowSummary deprecation',
    Content => 'This is a test ticket',
);
ok( $ticket && $ticket->id, 'created test ticket' );

# Test calling the deprecated ShowSummary template
{
    # Call the ShowSummary template via our test page
    $m->get_ok( $baseurl . '/ShowSummaryTest.html?id=' . $ticket->id );

    # Check that we get the expected deprecation warning
    $m->next_warning_like( qr/ShowSummary is deprecated.*will be removed in RT 6\.2.*PageLayoutMapping/, 'Found ShowSummary deprecation warning' );

    # Check that the page loads (even if deprecated)
    $m->content_contains( 'ShowSummary Test', 'ShowSummary test page loads' );

    # Verify the template actually worked by checking for key sections
    $m->content_contains( 'The Basics', 'ShowSummary displays ticket basics section' );
    $m->content_contains( 'People', 'ShowSummary displays people section' );
    $m->content_contains( 'Dates', 'ShowSummary displays dates section' );
    $m->content_contains( 'Links', 'ShowSummary displays links section' );

    # Check that the ticket ID appears which proves the template was called with the ticket
    $m->content_contains( '#' . $ticket->id, 'ShowSummary shows ticket ID' );
}

done_testing;
