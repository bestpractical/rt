use strict;
use warnings;

use RT::Test no_plan => 1;
my ( $url, $m ) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for (['x', 50], ['y', 40], ['z', 30]) {
    $ticket->Create(
        Subject   => $_->[0],
        Queue     => 'general',
        Owner     => 'root',
        Priority  => $_->[1],
        Requestor => 'root@localhost',
    );
}

ok( $m->login, 'logged in' );

$m->get($url . '/Search/Build.html?NewQuery=1');
$m->form_name('BuildQuery');
$m->field(ValueOfPriority => 45);
$m->click('DoSearch');
#RT->Logger->error($m->uri); sleep 100;
#{ open my $fh, '>', 'm.html'; print $fh $m->content; close $fh; }; die;
$m->text_contains('Found 2 tickets');

$m->follow_link(id => 'page-edit_search');
$m->form_name('BuildQuery');
$m->field(ValueOfAttachment => 'z');
$m->click('DoSearch');

$m->text_contains('Found 1 ticket');

$m->follow_link(id => 'page-bulk');

$m->form_name('BulkUpdate');
ok(!$m->value('UpdateTicket2'), "There is no Ticket #2 in the search's bulk update");

sub edit_search_link_has {
    my ($m, $id, $msg) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    (my $dec_id = $id) =~ s/:/%3A/g;

    my $chart_url = $m->find_link(id => 'page-edit_search')->url;
    like(
        $chart_url, qr{SavedSearchId=\Q$dec_id\E},
        $msg || 'Search link matches the pattern we expected'
    );
}

diag("Test search context");
{
    $m->get_ok($url . '/Search/Build.html');
    $m->form_name('BuildQuery');
    $m->field(ValueOfPriority => 45);
    $m->click('AddClause');
    $m->form_name('BuildQuery');
    $m->set_fields(
        SavedSearchDescription => 'my saved search',
    );
    $m->click('SavedSearchSave');

    my $saved_search_id = $m->form_name('BuildQuery')->value('SavedSearchId');
    edit_search_link_has($m, $saved_search_id);
}
