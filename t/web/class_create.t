use strict;
use warnings;

use RT::Test tests => 13;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $class_name = 'test class';

my $class_id;
diag "Create a class";
{
    $m->follow_link( id => 'admin-articles-classes-create');

    # Test class form validation
    $m->submit_form(
        form_name => 'ModifyClass',
        fields => {
            Name => '',
        },
    );
    $m->text_contains('Invalid value for Name');
    $m->submit_form(
        form_name => 'ModifyClass',
        fields => {
            Name => '0',
        },
    );
    $m->text_contains('Invalid value for Name');
    $m->submit_form(
        form_name => 'ModifyClass',
        fields => {
            Name => '1',
        },
    );
    $m->text_contains('Invalid value for Name');
    $m->submit_form(
        form_name => 'ModifyClass',
        fields => {
            Name => $class_name,
        },
    );
    $m->content_contains('Object created', 'created class sucessfully' );

    # Test validation on updae
    $m->form_name('ModifyClass');
    $m->set_fields(
        Name => '',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $m->form_name('ModifyClass');
    $m->set_fields(
        Name => '0',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $m->form_name('ModifyClass');
    $m->set_fields(
        Name => '1',
    );
    $m->click_button(value => 'Save Changes');
    $m->text_contains('Illegal value for Name');

    $class_id           = $m->form_name('ModifyClass')->value('id');
    ok $class_id, "found id of the class in the form, it's #$class_id";
}

