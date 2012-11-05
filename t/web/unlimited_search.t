use strict;
use warnings;

use RT::Test tests => 85;
my ($baseurl, $agent) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for ( 1 .. 75 ) {
    ok $ticket->Create(
        Subject   => 'Ticket ' . $_,
        Queue     => 'General',
        Owner     => 'root',
        Requestor => 'unlimitedsearch@localhost',
    );
}

ok $agent->login('root', 'password'), 'logged in as root';

$agent->get_ok('/Search/Build.html');
$agent->form_name('BuildQuery');
$agent->field('idOp', '>');
$agent->field('ValueOfid', '0');
$agent->submit('AddClause');
$agent->form_name('BuildQuery');
$agent->field('RowsPerPage', '0');
$agent->submit('DoSearch');
$agent->follow_link_ok({text=>'Show Results'});
$agent->content_contains("Ticket 75");

$agent->follow_link_ok({text=>'New Search'});
$agent->form_name('BuildQuery');
$agent->field('idOp', '>');
$agent->field('ValueOfid', '0');
$agent->submit('AddClause');
$agent->form_name('BuildQuery');
$agent->field('RowsPerPage', '50');
$agent->submit('DoSearch');
$agent->follow_link_ok({text=>'Bulk Update'});
$agent->content_lacks("Ticket 51");
