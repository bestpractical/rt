use strict;
use warnings;

use RT::Test tests => undef;
my ( $url, $m ) = RT::Test->started_ok;
use RT::Attribute;

my $search = RT::Attribute->new(RT->SystemUser);
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
my ($owner) = $m->content =~ /value="(RT::User-\d+)"/;

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchDescription => 'first chart',
        SavedSearchOwner       => $owner,
    },
    button => 'SavedSearchSave',
);

$m->content_contains("Chart first chart saved", 'saved first chart' );

my ( $search_uri, $id ) = $m->content =~ /value="(RT::User-\d+-SavedSearch-(\d+))"/;
$m->submit_form(
    form_name => 'SaveSearch',
    fields    => { SavedSearchLoad => $search_uri },
);

$m->content_like( qr/name="SavedSearchDelete"\s+value="Delete"/,
    'found Delete button' );
$m->content_like(
    qr/name="SavedSearchDescription"\s+value="first chart"/,
    'found Description input with the value filled'
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
is( $search->SubValue('Query'), 'id=2', 'Query is indeed updated' );
is( $search->SubValue('GroupBy'),
    'Status', 'GroupBy is indeed updated' );
is( $search->SubValue('ChartStyle'), 'pie', 'ChartStyle is indeed updated' );

# finally, let's test delete
$m->submit_form(
    form_name => 'SaveSearch',
    button    => 'SavedSearchDelete',
);
$m->content_contains("Chart first chart deleted", 'found deleted message' );
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
    $m->field(SavedSearchDescription => $_->[0]);
    $m->click_ok('SavedSearchSave');
    $m->text_contains('Chart ' . $_->[0] . ' saved.');

}

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchDescription => 'a copy',
        SavedSearchOwner       => $owner,
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
    my ($from) = $saved_search_ids[1] =~ /SavedSearch-(\d+)$/;
    my ($to)   = $saved_search_ids[2] =~ /SavedSearch-(\d+)$/;
    my $from_attr = RT::Attribute->new( RT->SystemUser );
    $from_attr->Load($from);
    ok( $from_attr->Id, "Found attribute #$from" );
    my $to_attr = RT::Attribute->new( RT->SystemUser );
    $to_attr->Load($to);
    ok( $to_attr->Id, "Found attribute #$to" );
    is_deeply( $from_attr->Content, $to_attr->Content, 'Chart copy content is correct' );
}

diag "saving a chart without changing its config shows up on dashboards (I#31557)";
{
    $m->get_ok( $url . "/Search/Chart.html?Query=" . 'id!=-1' );
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchDescription => 'chart without updates',
            SavedSearchOwner       => $owner,
        },
        button => 'SavedSearchSave',
    );

    $m->form_name('SaveSearch');
    @saved_search_ids =
        $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids; # first value is blank
    my $chart_without_updates_id = $saved_search_ids[3];
    ok($chart_without_updates_id, 'got a saved chart id');

    my ($privacy, $user_id, $search_id) = $chart_without_updates_id =~ /^(RT::User-(\d+))-SavedSearch-(\d+)$/;
    my $user = RT::User->new(RT->SystemUser);
    $user->Load($user_id);
    is($user->Name, 'root', 'loaded user');
    my $currentuser = RT::CurrentUser->new($user);

    my $search = RT::SavedSearch->new($currentuser);
    $search->Load($privacy, $search_id);
    is($search->Name, 'chart without updates', 'loaded search');
    is($search->GetParameter('ChartStyle'), 'bar+table+sql', 'chart correctly initialized with default ChartStyle');
    is($search->GetParameter('Height'), undef, 'no height by default');
    is($search->GetParameter('Width'), undef, 'no width by default');
    is($search->GetParameter('Query'), 'id!=-1', 'chart correctly initialized with Query');
    is($search->GetParameter('SearchType'), 'Chart', 'chart correctly initialized with SearchType');
    is_deeply($search->GetParameter('GroupBy'), ['Status'], 'chart correctly initialized with default GroupBy');
    is_deeply($search->GetParameter('ChartFunction'), ['COUNT'], 'chart correctly initialized with default ChartFunction');
}

diag "test chart content with default parameters";
{
    $m->get_ok( $url . "/Search/Chart.html?Query=" . 'id!=-1' );
    $m->follow_link_ok( { text => 'Chart' } );    # Get all the default parameters
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchDescription => 'chart with default parameters',
            SavedSearchOwner       => $owner,
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

    my ( $privacy, $user_id, $search_id ) = $chart_id =~ /^(RT::User-(\d+))-SavedSearch-(\d+)$/;
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($user_id);
    is( $user->Name, 'root', 'loaded user' );
    my $currentuser = RT::CurrentUser->new($user);

    my $search = RT::SavedSearch->new($currentuser);
    $search->Load( $privacy, $search_id );
    ok( !exists $search->{Attribute}->Content->{''}, 'No empty key' );
}

diag 'testing transaction saved searches';
{
    $m->get_ok("/Search/Chart.html?Class=RT::Transactions&Query=Type=Create");
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchDescription => 'txn chart 1',
            SavedSearchOwner       => $owner,
        },
        button => 'SavedSearchSave',
    );
    $m->form_name('SaveSearch');
    @saved_search_ids = $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids;    # first value is blank
    my $chart_without_updates_id = $saved_search_ids[0];
    ok( $chart_without_updates_id, 'got a saved chart id' );
    is( scalar @saved_search_ids, 1, 'got only one saved chart id' );

    my ( $privacy, $user_id, $search_id ) = $chart_without_updates_id =~ /^(RT::User-(\d+))-SavedSearch-(\d+)$/;
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($user_id);
    is( $user->Name, 'root', 'loaded user' );
    my $currentuser = RT::CurrentUser->new($user);

    my $search = RT::SavedSearch->new($currentuser);
    $search->Load( $privacy, $search_id );
    is( $search->Name, 'txn chart 1', 'loaded search' );
}


diag 'testing asset saved searches';
{
    $m->get_ok("/Search/Chart.html?Class=RT::Assets&Query=id>0");
    $m->submit_form(
        form_name => 'SaveSearch',
        fields    => {
            SavedSearchDescription => 'asset chart 1',
            SavedSearchOwner       => $owner,
        },
        button => 'SavedSearchSave',
    );
    $m->form_name('SaveSearch');
    @saved_search_ids = $m->current_form->find_input('SavedSearchLoad')->possible_values;
    shift @saved_search_ids;    # first value is blank
    my $chart_without_updates_id = $saved_search_ids[0];
    ok( $chart_without_updates_id, 'got a saved chart id' );
    is( scalar @saved_search_ids, 1, 'got only one saved chart id' );

    my ( $privacy, $user_id, $search_id ) = $chart_without_updates_id =~ /^(RT::User-(\d+))-SavedSearch-(\d+)$/;
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($user_id);
    is( $user->Name, 'root', 'loaded user' );
    my $currentuser = RT::CurrentUser->new($user);

    my $search = RT::SavedSearch->new($currentuser);
    $search->Load( $privacy, $search_id );
    is( $search->Name, 'asset chart 1', 'loaded search' );
}

done_testing;
