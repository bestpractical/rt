use strict;
use warnings;

use RT::Test tests => 13;

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

