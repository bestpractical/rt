use strict;
use warnings;

use Test::Deep;
use Data::Dumper ();

use RT::Test tests => undef, config => 'Set($ShowEditSystemConfig, 0);';

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok( { text => 'System Configuration' }, 'followed link to "System Configuration"' );
ok( !$m->find_link( text => 'Edit' ), 'no edit link' );
$m->get_ok('/Admin/Tools/EditConfig.html');
$m->content_contains('Permission Denied');
$m->warning_like( qr/Permission Denied/, 'Permission denied warning' );

RT::Test->stop_server;
RT->Config->Set( ShowEditSystemConfig => 1 );

( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok( { text => 'System Configuration' }, 'followed link to "System Configuration"' );
$m->follow_link_ok( { text => 'History' }, 'followed link to History page' );
$m->follow_link_ok( { text => 'Edit' }, 'followed link to Edit page' );

# In the tests below, new_value is *always* the string we feed
# into the Web form.  For compound objects such as hashes and arrays,
# we have a separate expected member that is the Perl data structure
# resulting from feeding new_value into the Web interface.
my $tests = [
    {
        name      => 'change a string value',
        form_id   => 'form-System-Base_configuration',
        setting   => 'CorrespondAddress',
        new_value => 'rt-correspond-edited@example.com',
    },
    {
        name      => 'change a boolean value',
        form_id   => 'form-System-Outgoing_mail',
        setting   => 'NotifyActor',
        new_value => 1,
    },
    {
        name      => 'change an arrayref value',
        form_id   => 'form-System-Extra_security',
        setting   => 'ReferrerWhitelist',
        new_value => '["www.example.com:443", "www3.example.com:80"]',
        expected  => ['www.example.com:443', 'www3.example.com:80'],
    },
    {
        name      => 'change a hashref value',
        form_id   => 'form-System-Outgoing_mail',
        setting   => 'OverrideOutgoingMailFrom',
        new_value => '{"1":"new-outgoing-from@example.com"}',
        expected  => {1 => 'new-outgoing-from@example.com'},
    },
    {
        name      => 'change CustomFieldGroupings',
        form_id   => 'form-Web_interface-Base_configuration',
        setting   => 'CustomFieldGroupings',
        new_value => '{ "RT::Ticket": [ "Grouping Name", [ "CF Name" ] ] }',
        expected  => { 'RT::Ticket' => [ 'Grouping Name', [ 'CF Name' ] ] },
        converted => { 'RT::Ticket' => { Default =>  [ 'Grouping Name', [ 'CF Name' ] ] } },
    },
];

run_test( %{$_} ) for @{$tests};

# check tx log for configuration
my $transactions = RT::Transactions->new(RT->SystemUser);
$transactions->Limit(FIELD => 'ObjectType', VALUE =>  'RT::Configuration');
$transactions->OrderBy(FIELD => 'Created', ORDER => 'ASC');
my $tx_items = $transactions->ItemsArrayRef;

my $i = 0;
foreach my $change (@{$tests}) {
    check_transaction( $tx_items->[$i++], $change );
}

# check config history page
$m->get_ok( $url . '/Admin/Tools/ConfigHistory.html');
$i = 0;
foreach my $change (@{$tests}) {
    check_history_page_item($tx_items->[$i++], $change );
}

# Test pagination with PerPage=2 (5 items total = 3 pages)
diag "Test pagination";

$m->get_ok( $url . '/Admin/Tools/ConfigHistory.html?PerPage=2', 'Get history with PerPage=2' );
my $dom = $m->dom;
my $paging = $dom->at('div.paging');
ok( $paging, 'Pagination div exists' );
my $pagination_ul = $paging->at('ul.pagination');
ok( $pagination_ul, 'Pagination list exists' );

# Page 1 should be active
my $active_item = $pagination_ul->at('li.page-item.active');
ok( $active_item, 'Active page item exists' );
is( $active_item->at('a')->text, '1', 'Page 1 is active' );

# Should have links to pages 2 and 3
ok( $m->find_link( url_regex => qr/Page=2/ ), 'Link to page 2 exists' );
ok( $m->find_link( url_regex => qr/Page=3/ ), 'Link to page 3 exists' );

# Count history items on page 1 - should be 2
my @history_items = $dom->find('div.history-container div.transaction')->each;
is( scalar @history_items, 2, 'Page 1 shows 2 history items' );

# Go to page 2 by clicking the pagination link
$m->follow_link_ok( { text => '2', url_regex => qr/Page=2/ }, 'Click page 2 link' );
$dom = $m->dom;
$active_item = $dom->at('div.paging ul.pagination li.page-item.active');
ok( $active_item, 'Active page item exists on page 2' );
is( $active_item->at('a')->text, '2', 'Page 2 is active' );

@history_items = $dom->find('div.history-container div.transaction')->each;
is( scalar @history_items, 2, 'Page 2 shows 2 history items' );

# Go to page 3 by clicking the pagination link
$m->follow_link_ok( { text => '3', url_regex => qr/Page=3/ }, 'Click page 3 link' );
$dom = $m->dom;
$active_item = $dom->at('div.paging ul.pagination li.page-item.active');
ok( $active_item, 'Active page item exists on page 3' );
is( $active_item->at('a')->text, '3', 'Page 3 is active' );

@history_items = $dom->find('div.history-container div.transaction')->each;
is( scalar @history_items, 1, 'Page 3 shows 1 history item (last page)' );

sub run_test {
    my %args = @_;

    diag $args{name} if $ENV{TEST_VERBOSE};

    $m->form_id( $args{form_id} );
    $m->untick( "$args{setting}-file", 1 );
    $m->submit_form_ok(
        {
            fields  => {
                $args{setting} => $args{new_value},
            },
        },
        'form was submitted successfully'
    );

    # RT::Config in the test is not running in the same process as the one in the test server.
    # ensure the config object in the test is up to date with the changes.
    RT->Config->LoadConfigFromDatabase();
    RT->Config->PostLoadCheck;

    $m->content_like( qr/$args{setting} changed from/, 'UI indicated the value was changed' );

    # RT::Configuration->Content returns the value as string.
    # in the test below we need to also ensure the new value is string.
    my $rt_configuration = RT::Configuration->new( RT->SystemUser );
    $rt_configuration->Load( $args{setting} );
    my $rt_configuration_value = $rt_configuration->Content;

    my $rt_config_value = RT->Config->Get( $args{setting} );

    is( $rt_configuration_value, stringify($args{expected}) || $args{new_value}, 'value from RT::Configuration->Load matches new value' );
    cmp_deeply( $rt_config_value, $args{converted} || $args{expected} || $args{new_value}, 'value from RT->Config->Get matches new value' );
}

sub check_transaction {
    my ($tx, $change) = @_;
    is($tx->ObjectType, 'RT::Configuration', 'tx is config change');
    is($tx->Field, $change->{setting}, 'tx matches field changed');
    is($tx->NewValue, stringify($change->{expected}) || $change->{new_value}, 'tx value matches');
}

sub check_history_page_item {
    my ($tx, $change) = @_;
    my $link = sprintf('ConfigHistory.html?id=%d#txn-%d', $tx->ObjectId, $tx->id);
    ok($m->find_link(url => $link), 'found tx link in history');
    if ($change->{expected}) {
        $m->text_contains(compactify($change->{expected}), 'fetched tx has new value');
    } else {
        $m->text_contains($change->{new_value});
    }
    $m->text_like(qr/$change->{setting} (?:added|changed)/, 'fetched tx has changed field');
}

sub compactify {
    my $value = stringify(shift);
    $value =~ s/\s+/ /g;
    return $value;
}

sub stringify {
    my $value = shift;

    return $value unless ref $value;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 2;
    local $Data::Dumper::Sortkeys = 1;

    my $output = Data::Dumper::Dumper $value;
    chomp $output;
    return $output;
}

done_testing;
