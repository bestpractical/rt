use strict;
use warnings;


use RT::Test tests => 21;
my ($baseurl, $agent) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for ( 1 .. 3 ) {
    $ticket->Create(
        Subject   => 'Ticket ' . $_,
        Queue     => 'General',
        Owner     => 'root',
        Requestor => 'clownman@localhost',
    );
}

ok $agent->login('root', 'password'), 'logged in as root';

# [issues.bestpractical.com #16841] {
$agent->get_ok('/Search/Build.html');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '1');
$agent->submit('AddClause');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '2');
$agent->field('AndOr', 'OR');
$agent->submit('AddClause');

$agent->follow_link_ok({id => 'page-results'});
$agent->title_is('Found 2 tickets');
# }

# [issues.bestpractical.com #17237] {
$agent->follow_link_ok({text => 'New Search'});
$agent->title_is('Query Builder');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '1');
$agent->submit('AddClause');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '2');
$agent->field('AndOr', 'OR');
$agent->click_button(name => 'DoSearch');

$agent->title_is('Found 2 tickets');

$agent->follow_link_ok({id => 'page-results'});
$agent->title_is('Found 2 tickets');
# }

$agent->follow_link_ok({text => 'Chart'});
$agent->text_contains('id = 1 OR id = 2');
$agent->form_name('SaveSearch');
$agent->field('SavedSearchDescription' => 'this is my saved chart');
$agent->click_button(name => 'SavedSearchSave');

# Confirm that we saved the chart and that it's the "current chart"
$agent->text_contains('Chart this is my saved chart saved.');
$agent->form_name('SaveSearch');
is($agent->value('SavedSearchDescription'), 'this is my saved chart');

$agent->follow_link_ok({text => 'Edit Search'});
$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '3');
$agent->field('AndOr', 'OR');
$agent->click_button(name => 'DoSearch');

$agent->title_is('Found 3 tickets');

$agent->follow_link_ok({text => 'Chart'});
$agent->text_contains('id = 1 OR id = 2 OR id = 3');

# The interesting bit: confirm that the chart we saved is still the
# "current chart" after roundtripping through search builder
$agent->form_name('SaveSearch');
is($agent->value('SavedSearchDescription'), 'this is my saved chart');

