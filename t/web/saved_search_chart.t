use strict;
use warnings;

use RT::Test tests => undef;
my ( $url, $m ) = RT::Test->started_ok;
use RT::Attribute;

my $search = RT::SavedSearch->new(RT->SystemUser);
my $ticket = RT::Ticket->new(RT->SystemUser);
my ( $ret, $msg ) = $ticket->Create(
    Subject   => 'base ticket' . $$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'root@localhost',
    MIMEObj   => MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'base ticket' . $$,
        Data    => "",
    ),
);
ok( $ret, "ticket created: $msg" );

ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Search/Chart.html?Query=" . 'id=1' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName => 'first chart',
    },
    button => 'SavedSearchSave',
);

$m->content_contains("Chart first chart saved", 'saved first chart' );

my $id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];
$m->submit_form(
    form_name => 'SaveSearch',
    fields    => { SavedSearchLoad => $id },
);

$m->content_like(
    qr/name="SavedSearchName"\s+value="first chart"/,
    'found Name input with the value filled'
);
$m->content_like( qr/name="SavedSearchSave"\s+value="Update"/,
    'found Update button' );
$m->content_unlike( qr/name="SavedSearchSave"\s+value="Save"/,
    'no Save button' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        Query          => 'id=2',
        GroupBy        => 'Status',
        ChartStyle     => 'pie',
    },
    button => 'SavedSearchSave',
);

$m->content_contains("Chart first chart updated", 'found updated message' );
$m->content_contains("id=2",                      'Query is updated' );
$m->content_like( qr/value="Status"\s+selected="selected"/,
    'GroupBy is updated' );
$m->content_like( qr/value="pie"\s+selected="selected"/,
    'ChartType is updated' );
ok( $search->Load($id) );
is( $search->Content->{'Query'}, 'id=2', 'Query is indeed updated' );
is( $search->Content->{'GroupBy'},
    'Status', 'GroupBy is indeed updated' );
is( $search->Content->{'ChartStyle'}, 'pie', 'ChartStyle is indeed updated' );

# finally, let's test disabled
$m->form_name('SaveSearch');
$m->untick( 'SavedSearchEnabled', 1 );
$m->submit_form( button => 'SavedSearchSave', );
$m->content_contains("Chart first chart updated", 'found update message' );
$m->content_unlike( qr/value="RT::User-\d+-SavedSearch-\d+"/,
    'no saved search' );

for ('A' .. 'F') {
    $ticket->Create(
        Subject   => $$ . $_,
    );
}

for ([A => 'subject="'.$$.'A"'], [BorC => 'subject="'.$$.'B" OR subject="'.$$.'C"']) {
    $m->get_ok('/Search/Edit.html');
    $m->form_name('BuildQueryAdvanced');
    $m->field('Query', $_->[1]);
    $m->submit;

    # Save the search
    $m->follow_link_ok({id => 'page-chart'});
    $m->form_name('SaveSearch');
    $m->field(SavedSearchName => $_->[0]);
    $m->click_ok('SavedSearchSave');
    $m->text_contains('Chart ' . $_->[0] . ' saved.');

}

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName => 'a copy',
    },
    button => 'SavedSearchCopy',
);
$m->text_contains('Chart a copy saved.');

$m->form_name('SaveSearch');
my @saved_search_ids =
    $m->current_form->find_input('SavedSearchLoad')->possible_values;
shift @saved_search_ids; # first value is blank

cmp_ok(@saved_search_ids, '==', 3, '3 saved charts were made');

# TODO get find_link('page-chart')->URI->params to work...
sub page_chart_link_has {
    my ($m, $id, $msg) = @_;

    $Test::Builder::Level = $Test::Builder::Level + 1;

    (my $dec_id = $id) =~ s/:/%3A/g;

    my $chart_url = $m->find_link(id => 'page-chart')->url;
    like(
        $chart_url, qr{SavedChartSearchId=\Q$dec_id\E},
        $msg || 'Page chart link matches the pattern we expected'
    );
}

for my $i ( 0 .. 2 ) {
    $m->form_name('SaveSearch');

    # load chart $saved_search_ids[$i]
    $m->field( 'SavedSearchLoad' => $saved_search_ids[$i] );
    $m->click('SavedSearchLoadSubmit');
    page_chart_link_has( $m, $saved_search_ids[$i] );
    is( $m->form_number(3)->value('SavedChartSearchId'), $saved_search_ids[$i] );
}

diag "testing the content of chart copy content";
{
    my $from = RT::SavedSearch->new( RT->SystemUser );
    $from->Load($saved_search_ids[1]);
    ok( $from->Id, "Found search #$from" );
    my $to = RT::SavedSearch->new( RT->SystemUser );
    $to->Load($saved_search_ids[2]);
    ok( $to->Id, "Found search #$to" );
    is_deeply( $from->Content, $to->Content, 'Chart copy content is correct' );
}

diag "saving a chart without changing its config shows up on dashboards (I#31557)";
{
    $m->get_ok( $url . "/Search/Chart.html?Query=" . 'id!=-1' );
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchName => 'chart without updates',
        },
        button => 'SavedSearchSave',
    );

    $m->form_name('SaveSearch');
    @saved_search_ids =
        $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids; # first value is blank
    my $chart_without_updates_id = $saved_search_ids[3];
    ok($chart_without_updates_id, 'got a saved chart id');

    my $search = RT::SavedSearch->new(RT->SystemUser);
    $search->Load($chart_without_updates_id);
    is($search->Name, 'chart without updates', 'loaded search');
    is($search->Content->{'ChartStyle'}, 'bar+table+sql', 'chart correctly initialized with default ChartStyle');
    is($search->Content->{'Height'}, undef, 'no height by default');
    is($search->Content->{'Width'}, undef, 'no width by default');
    is($search->Content->{'Query'}, 'id!=-1', 'chart correctly initialized with Query');
    is($search->Type, 'TicketChart', 'chart correctly initialized with Type');
    is_deeply($search->Content->{'GroupBy'}, ['Status'], 'chart correctly initialized with default GroupBy');
    is_deeply($search->Content->{'ChartFunction'}, ['COUNT'], 'chart correctly initialized with default ChartFunction');
}

diag "test chart content with default parameters";
{
    $m->get_ok( $url . "/Search/Chart.html?Query=" . 'id!=-1' );
    $m->follow_link_ok( { text => 'Chart' } );    # Get all the default parameters
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchName => 'chart with default parameters',
        },
        button => 'SavedSearchSave',
    );

    $m->form_name('SaveSearch');
    my $load_select = $m->current_form->find_input('SavedSearchLoad');
    my @labels      = $load_select->value_names;
    my @values      = $load_select->possible_values;
    require List::MoreUtils;
    my %label_value = List::MoreUtils::mesh( @labels, @values );

    my $chart_id = $label_value{'chart with default parameters'};
    ok( $chart_id, 'got a saved chart id' );

    my $search = RT::SavedSearch->new(RT->SystemUser);
    $search->Load($chart_id);
    ok( !exists $search->Content->{''}, 'No empty key' );
}

diag 'testing transaction saved searches';
{
    $m->get_ok("/Search/Chart.html?Class=RT::Transactions&Query=Type=Create");
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchName => 'txn chart 1',
        },
        button => 'SavedSearchSave',
    );
    $m->form_name('SaveSearch');
    @saved_search_ids = $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids;    # first value is blank
    my $chart_without_updates_id = $saved_search_ids[0];
    ok( $chart_without_updates_id, 'got a saved chart id' );
    is( scalar @saved_search_ids, 1, 'got only one saved chart id' );

    my $search = RT::SavedSearch->new(RT->SystemUser);
    $search->Load( $chart_without_updates_id );
    is( $search->Name, 'txn chart 1', 'loaded search' );
}


diag 'testing asset saved searches';
{
    $m->get_ok("/Search/Chart.html?Class=RT::Assets&Query=id>0");
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchName => 'asset chart 1',
        },
        button => 'SavedSearchSave',
    );
    $m->form_name('SaveSearch');
    @saved_search_ids = $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids;    # first value is blank
    my $chart_without_updates_id = $saved_search_ids[0];
    ok( $chart_without_updates_id, 'got a saved chart id' );
    is( scalar @saved_search_ids, 1, 'got only one saved chart id' );

    my $search = RT::SavedSearch->new(RT->SystemUser);
    $search->Load( $chart_without_updates_id );
    is( $search->Name, 'asset chart 1', 'loaded search' );
}

done_testing;
