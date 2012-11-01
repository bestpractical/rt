use strict;
use warnings;

use RT::Test tests => 26;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

{
    diag "test creating a group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_contains('Group created', 'found results');
    $m->content_contains('Modify the group test group', 'found title');
}

{
    diag "test creating another group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group2' },
    });
    $m->content_contains('Group created', 'found results');
    $m->content_contains('Modify the group test group2', 'found title');
}

{
    diag "test creating an overlapping group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_contains('Group could not be created', 'found results');
    $m->content_like(qr/Group name .+? is already in use/, 'found message');
}

{
    diag "test updating a group name to overlap" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/' );
    $m->follow_link_ok({text => 'test group2'}, 'found title');
    $m->content_contains('Modify the group test group2');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_lacks('Name changed', "name not changed");
    $m->content_contains('Illegal value for Name', 'found error message');
    $m->content_contains('test group', 'did not find new name');
}

