use strict;
use warnings;

use RT::Test tests => 30;
my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'ticket foo' },
    { Subject => 'ticket bar' },
);

ok( $m->login, 'logged in' );

$m->get_ok('/Search/Simple.html');
$m->content_lacks( 'Show Results', 'no page menu' );
$m->get_ok('/Search/Simple.html?q=ticket foo');
$m->content_contains( 'Show Results',   "has page menu" );
$m->title_is( 'Found 1 ticket', 'title' );
$m->content_contains( 'ticket foo', 'has ticket foo' );

# Test searches on custom fields
my $cf1 = RT::Test->load_or_create_custom_field(
                      Name  => 'Location',
                      Queue => 'General',
                      Type  => 'FreeformSingle', );
isa_ok( $cf1, 'RT::CustomField' );

my $cf2 = RT::Test->load_or_create_custom_field(
                      Name  => 'Server-name',
                      Queue => 'General',
                      Type  => 'FreeformSingle', );
isa_ok( $cf2, 'RT::CustomField' );

my $t = RT::Ticket->new(RT->SystemUser);

{
  my ($id,undef,$msg) = $t->Create(
            Queue => 'General',
            Subject => 'Test searching CFs');
  ok( $id, "Created ticket - $msg" );
}

{
  my ($status, $msg) = $t->AddCustomFieldValue(
                           Field => $cf1->id,
                           Value => 'Downtown');
  ok( $status, "Added CF value - $msg" );
}

{
  my ($status, $msg) = $t->AddCustomFieldValue(
                           Field => $cf2->id,
                           Value => 'Proxy');
  ok( $status, "Added CF value - $msg" );
}

# Regular search
my $search = 'cf.Location:Downtown';
$m->get_ok("/Search/Simple.html?q=$search");
$m->title_is( 'Found 1 ticket', 'Found 1 ticket' );
$m->text_contains( 'Test searching CFs', "Found test CF ticket with $search" );

# Case insensitive
$search = "cf.Location:downtown";
$m->get_ok("/Search/Simple.html?q=$search");
$m->title_is( 'Found 1 ticket', 'Found 1 ticket' );
$m->text_contains( 'Test searching CFs', "Found test CF ticket with $search" );

# With dash in CF name
$search = "cf.Server-name:Proxy";
$m->get_ok("/Search/Simple.html?q=$search");
$m->title_is( 'Found 1 ticket', 'Found 1 ticket' );
$m->text_contains( 'Test searching CFs', "Found test CF ticket with $search" );

# TODO more simple search tests
