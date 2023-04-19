use strict;
use warnings;

use RT::Test tests => undef;
RT::Config->Set('ShredderStoragePath', RT::Test->temp_directory . '');

my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Shortener test',
    Content => 'test',
);

ok $m->login, 'logged in';

$m->follow_link_ok( { text => 'New Search' } );
$m->submit_form_ok(
    {   form_name => 'BuildQuery',
        fields    => { ValueOfid => 10 },
        button    => 'DoSearch',
    }
);

my @menus = (
    { text        => 'Edit Search',     url_regex => qr{/Search/Build\.html\?sc=\w+} },
    { text        => 'Advanced',        url_regex => qr{/Search/Edit\.html\?sc=\w+} },
    { class_regex => qr/\bpermalink\b/, url_regex => qr{/Search/Edit\.html\?sc=\w+} },
    { text        => 'Show Results',    url_regex => qr{/Search/Results\.html\?sc=\w+} },
    { class_regex => qr/\bpermalink\b/, url_regex => qr{/Search/Results\.html\?sc=\w+} },
    { text        => 'Bulk Update',     url_regex => qr{/Search/Bulk\.html\?sc=\w+} },
    { class_regex => qr/\bpermalink\b/, url_regex => qr{/Search/Bulk\.html\?sc=\w+} },
    { text        => 'Chart',           url_regex => qr{/Search/Chart\.html\?sc=\w+} },

    # Chart page has new code which contains chart arguments.
    { class_regex => qr/\bpermalink\b/, url_regex => qr{/Search/Chart\.html\?sc=\w+} },
);

for my $menu (@menus) {
    $m->follow_link_ok($menu);
}

$m->follow_link_ok( { text => 'Advanced', url_regex => qr{/Search/Edit\.html\?sc=\w+} } );
$m->form_name('BuildQueryAdvanced');
is( $m->value('Query'), 'id < 10', 'Query on Advanced' );

$m->follow_link_ok( { text => 'Show Results', url_regex => qr{/Search/Results\.html\?sc=\w+} } );
$m->content_contains('Shortener test', 'Found the ticket');

my @feeds = (
    { text => 'Spreadsheet', url_regex => qr/\bsc=\w+/ },
    { text => 'RSS',         url_regex => qr/\bsc=\w+/ },
    { text => 'iCal',        url_regex => qr/\bsc-\w+/ },
);
for my $feed (@feeds) {
    $m->follow_link_ok($feed);
    $m->content_contains('Shortener test', 'Found the ticket');
    $m->back;
    last;
}

$m->follow_link_ok( { text => 'Shredder', url_regex => qr/\bsc=\w+/ } );
$m->form_id('shredder-search-form');
is( $m->value('Tickets:query'), 'id < 10', 'Tickets:query in shredder' );
is( $m->value('Tickets:limit'), 50,        'Tickets:limit in shredder' );


$m->get_ok('/Search/Build.html?Query=Queue="General"');
$m->submit_form_ok(
    {   form_name => 'BuildQuery',
        fields    => { SavedSearchDescription => 'my saved search' },
        button    => 'SavedSearchSave',
    },
    'Created saved search'
);
$m->follow_link_ok( { text => 'View', url_regex => qr{/Search/Build\.html\?sc=\w+} } );
$m->form_name('BuildQuery');
is( $m->value('SavedSearchDescription'), 'my saved search', 'Loaded saved search' );

$m->follow_link_ok( { text => 'Chart', url_regex => qr{/Search/Chart\.html\?.*\bsc=\w+} } );
$m->text_contains(q{Queue = 'General'});

$m->submit_form_ok(
    {   form_number => 3,
        fields      => { Width => 800, Height => 400 },
        button      => 'Update',
    },
    'Updaetd chart search'
);
$m->form_number(3);
is( $m->value('Width'),  800, 'Width is updated' );
is( $m->value('Height'), 400, 'Height is updated' );

$m->submit_form_ok(
    {   form_name => 'SaveSearch',
        fields    => { SavedSearchDescription => 'my chart saved search' },
        button    => 'SavedSearchSave',
    },
    'Created chart saved search'
);
$m->follow_link_ok( { text => 'View', url_regex => qr{/Search/Chart\.html\?sc=\w+} } );
$m->form_name('SaveSearch');
is( $m->value('SavedSearchDescription'), 'my chart saved search', 'Loaded chart saved search' );

$m->form_number(3);
is( $m->value('Width'),  800, 'Width is set' );
is( $m->value('Height'), 400, 'Height is set' );

done_testing;
