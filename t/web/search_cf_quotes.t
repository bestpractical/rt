use strict;
use warnings;

use RT::Test tests => 24;
my ( $baseurl, $m ) = RT::Test->started_ok;

my $cf = RT::CustomField->new($RT::SystemUser);
ok(
    $cf->Create(
        Name       => "I'm a cf",
        Type       => 'Date',
        LookupType => 'RT::Queue-RT::Ticket',
    )
);
ok( $cf->AddToObject( RT::Queue->new($RT::SystemUser) ) );

RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'ticket foo', 'CustomField-' . $cf->id => '2011-09-15' },
    { Subject => 'ticket bar', 'CustomField-' . $cf->id => '2011-10-15' },
    { Subject => 'ticket baz' },
);

ok( $m->login, 'logged in' );

$m->get_ok('/Search/Build.html');
$m->form_name( 'BuildQuery' );

my ($cf_op) =
  $m->find_all_inputs( type => 'option', name_regex => qr/I'm a cf/ );
my ($cf_field) =
  $m->find_all_inputs( type => 'text', name_regex => qr/I'm a cf/ );

diag "search directly";
$m->submit_form(
    fields    => { $cf_op->name => '<', $cf_field->name => '2011-09-30', },
    button    => 'DoSearch',
);

$m->title_is( 'Found 1 ticket', 'found only 1 ticket' );
$m->content_contains( 'ticket foo', 'has ticket foo' );

diag "first add clause, then search";
$m->get_ok('/Search/Build.html?NewQuery=1');
$m->form_name( 'BuildQuery' );
$m->submit_form(
    fields    => { $cf_op->name => '<', $cf_field->name => '2011-09-30', },
    button    => 'AddClause',
);
$m->follow_link_ok( { text => 'Show Results' } );
$m->title_is( 'Found 1 ticket', 'found only 1 ticket' );
$m->content_contains( 'ticket foo', 'has ticket foo' );

