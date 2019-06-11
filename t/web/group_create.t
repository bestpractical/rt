use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $group_name = 'test group';

my $group_id;
diag "Create a group";
{
    $m->follow_link( id => 'admin-groups-create');

    # Test group form validation
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '',
        },
    );
    $m->text_contains('Name is required');
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '0',
        },
    );
    $m->text_contains('Could not create group');
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '1',
        },
    );
    $m->text_contains('Could not create group');
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => $group_name,
        },
    );
    $m->content_contains('Group created', 'created group sucessfully' );

    # Test validation on updae
    $m->form_name('ModifyGroup');
    $m->set_fields(
        Name => '',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $m->form_name('ModifyGroup');
    $m->set_fields(
        Name => '0',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $m->form_name('ModifyGroup');
    $m->set_fields(
        Name => '1',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $group_id           = $m->form_name('ModifyGroup')->value('id');
    ok $group_id, "found id of the group in the form, it's #$group_id";
}

ok($m->logout(), 'Logged out');

{
    my $tester = RT::Test->load_or_create_user( Name => 'staff1', Password => 'password' );
    ok $m->login( $tester->Name, 'password' ), 'Logged in';

    $m->get('/Admin/Groups/');
    is( $m->status, 403, "No access without ShowConfigTab" );

    RT::Test->set_rights(
        { Principal => $tester->PrincipalObj,
          Right => [qw(ShowConfigTab)],
        },
    );

    $m->get('/Admin/Groups/');
    is( $m->status, 200, "Can see group admin page" );

    load_group_admin_pages($m, $group_id, '403');

    ok($tester->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $RT::System), 'Grant SeeGroup');

    load_group_admin_pages($m, $group_id, '200');
}

sub load_group_admin_pages{
    my $m = shift;
    my $group_id = shift;
    my $status = shift;

    foreach my $page (qw(GroupRights Members Modify History Memberships ModifyLinks UserRights)){
        $m->get("/Admin/Groups/$page.html?id=$group_id");
        is( $m->status, $status, "Got $status for $page page");
    }
}

done_testing();
