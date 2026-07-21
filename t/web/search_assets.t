use strict;
use warnings;

use URI;
use RT::Test::Assets tests => undef;

RT::Test::Assets::create_assets(
    {   Catalog => 'General assets',
        Name    => 'iMac 27',
        Status  => 'new',

    },
    {   Catalog => 'General assets',
        Name    => 'Macbook Pro 2019',
        Status  => 'allocated',
    },
);

my ( $baseurl, $m ) = RT::Test->started_ok;

$m->login;

diag "Query builder";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Assets/ }, 'Query builder' );
    $m->title_is('Asset Query Builder');

    my $form = $m->form_name('BuildQuery');
    is_deeply( [$form->find_input('AttachmentField')->possible_values], [qw/Name Description/], 'AttachmentField options' );

    my @watcher_options = ( '', qw/Owner HeldBy Contact/ );
    is_deeply( [ $form->find_input('WatcherField')->possible_values ], \@watcher_options, 'WatcherField options' );
    my @watcher_sub_options = qw/EmailAddress Name RealName Nickname Organization Address1 Address2 City State Zip Country WorkPhone HomePhone MobilePhone PagerPhone id/;
    is_deeply( [ $form->find_input('WatcherFieldSubType')->possible_values ], \@watcher_sub_options, 'WatcherFieldSubType options' );

    $m->field( ValueOfCatalog => 'General assets' );
    $m->click('AddClause');

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 2 assets');

    $m->back;
    $m->form_name('BuildQuery');
    $m->field( ValueOfAttachment => 'iMac' );
    $m->click('AddClause');

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 1 asset');
    $m->text_contains('iMac 27');
}

diag "Advanced";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Assets/ }, 'Query builder' );
    $m->follow_link_ok( { text => 'Advanced' }, 'Advanced' );
    $m->title_is('Edit Asset Query');

    $m->form_name('BuildQueryAdvanced');
    $m->field( Query => q{Status = 'allocated'} );
    $m->submit;

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 1 asset');
    $m->text_contains('Macbook Pro 2019');
}

diag "Saved searches";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Assets/ }, 'Query builder' );
    $m->form_name('BuildQuery');
    $m->field( ValueOfCatalog => 'General assets' );
    $m->submit('AddClause');

    $m->form_name('BuildQuery');
    $m->field( SavedSearchName => 'test asset search' );
    $m->click('SavedSearchSave');
    $m->text_contains('Current search: test asset search');

    my $form  = $m->form_name('BuildQuery');
    my $input = $form->find_input('SavedSearchLoad');

    # an empty search and the real saved search
    is( scalar $input->possible_values, 2, '2 SavedSearchLoad options' );

    my ($id) = ( $input->possible_values )[1] =~ /(\d+)$/;
    my $search = RT::SavedSearch->new( RT->SystemUser );
    $search->Load($id);
    is($search->Type, 'Asset', 'Saved search type');
    is_deeply(
        $search->Content,
        {   'Order'  => 'ASC|ASC|ASC|ASC',
            'Format' => q{'<a href="__WebPath__/Asset/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebHomePath__/Asset/Display.html?id=__id__">__Name__</a>/TITLE:Name',
Status,
Catalog,
Owner,
'__ActiveTickets__ __InactiveTickets__/TITLE:Related tickets',
'__NEWLINE__',
'__NBSP__',
'<small>__Description__</small>',
'<small>__CreatedRelative__</small>',
'<small>__LastUpdatedRelative__</small>',
'<small>__Contacts__</small>'},
            'RowsPerPage' => '50',
            'OrderBy'     => 'Name|||',
            'ObjectType'  => '',
            'Query'       => 'Catalog = \'General assets\''
        },
        'Saved search content'
    );
}

diag "Active/Inactive options in the Status column filter (assets)";
{
    my $uri = URI->new( $baseurl . '/Views/Component/FilterAssets' );
    $uri->query_form( Attribute => 'Status', Query => 'id > 0' );
    $m->get_ok( $uri, 'Fetched FilterAssets Status panel' );
    $m->content_contains( 'value="__Active__"',   'Active option rendered' );
    $m->content_contains( 'value="__Inactive__"', 'Inactive option rendered' );
    $m->content_contains( '>Active<',   'Active label rendered' );
    $m->content_contains( '>Inactive<', 'Inactive label rendered' );

    my $applied = URI->new( $baseurl . '/Views/Component/FilterAssets' );
    $applied->query_form(
        Attribute => 'Status',
        Query     => '( id > 0 ) AND ( Status = "__Active__" )',
        BaseQuery => 'id > 0',
    );
    $m->get_ok( $applied, 'Fetched FilterAssets Status panel with __Active__ applied' );
    $m->content_like(
        qr/id="Status-__Active__"[^>]*checked/,
        'Active checkbox is checked when Status = "__Active__" is applied'
    );
    $m->content_unlike(
        qr/id="Status-__Inactive__"[^>]*checked/,
        'Inactive checkbox is not checked'
    );
}

done_testing;
