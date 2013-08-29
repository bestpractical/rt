use strict;
use warnings;

use RT::Test tests => 13;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $queue_name = 'test queue';

my $queue_id;
diag "Create a queue";
{
    $m->follow_link( id => 'admin-queues-create');

    # Test queue form validation
    $m->submit_form(
        form_name => 'ModifyQueue',
        fields => {
            Name => '',
        },
    );
    $m->text_contains('Queue name is required');
    $m->submit_form(
        form_name => 'ModifyQueue',
        fields => {
            Name => '0',
        },
    );
    $m->text_contains("'0' is not a valid name");
    $m->submit_form(
        form_name => 'ModifyQueue',
        fields => {
            Name => '1',
        },
    );
    $m->text_contains("'1' is not a valid name");
    $m->submit_form(
        form_name => 'ModifyQueue',
        fields => {
            Name => $queue_name,
        },
    );
    $m->content_contains('Queue created', 'created queue sucessfully' );

    # Test validation on update
    $m->form_name('ModifyQueue');
    $m->set_fields(
        Name => '',
    );
    $m->click_button(value => 'Save Changes');
    $m->content_contains('Illegal value for Name');

    $m->form_name('ModifyQueue');
    $m->set_fields(
        Name => '0',
    );
    $m->click_button(value => 'Save Changes');
    $m->content_contains('Illegal value for Name');

    $m->form_name('ModifyQueue');
    $m->set_fields(
        Name => '1',
    );
    $m->click_button(value => 'Save Changes');
    $m->content_contains('Illegal value for Name');

    $queue_id = $m->form_name('ModifyQueue')->value('id');
    ok $queue_id, "found id of the queue in the form, it's #$queue_id";
}

