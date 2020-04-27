use strict;
use warnings;

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

    my @watcher_options = ( '' );
    for my $role ( qw/Owner HeldBy Contact/ ) {
        for my $field ( qw/EmailAddress Name RealName Nickname Organization Address1 Address2 City State Zip Country WorkPhone HomePhone MobilePhone PagerPhone id/ ) {
            push @watcher_options, "$role.$field";
        }
    }
    is_deeply( [ $form->find_input('WatcherField')->possible_values ], \@watcher_options, 'WatcherField options' );

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
    $m->field( SavedSearchDescription => 'test asset search' );
    $m->click('SavedSearchSave');
    $m->text_contains('Current search: test asset search');

    my $form  = $m->form_name('BuildQuery');
    my $input = $form->find_input('SavedSearchLoad');

    # an empty search and the real saved search
    is( scalar $input->possible_values, 2, '2 SavedSearchLoad options' );

    my ($attr_id) = ( $input->possible_values )[1] =~ /(\d+)$/;
    my $attr = RT::Attribute->new( RT->SystemUser );
    $attr->Load($attr_id);
    is_deeply(
        $attr->Content,
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
            'SearchType'  => 'Asset',
            'RowsPerPage' => '50',
            'OrderBy'     => 'Name|||',
            'ObjectType'  => '',
            'Query'       => 'Catalog = \'General assets\''
        },
        'Saved search content'
    );
}

done_testing;
