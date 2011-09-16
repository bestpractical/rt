#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 10;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $group_name = 'test group';

my $group_id;
diag "Create a group";
{
    $m->follow_link( id => 'tools-config-groups-create');

    # Test group form validation
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '',
        },
    );
    $m->text_contains('A group name is required');
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '0',
        },
    );
    $m->text_contains('A group name is required');
    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => $group_name,
        },
    );
    $m->content_contains('Group created', 'created group sucessfully' );
    $group_id           = $m->form_name('ModifyGroup')->value('id');
    ok $group_id, "found id of the group in the form, it's #$group_id";

    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => '',
        },
    );
    $m->text_contains('Illegal value for Name');
}

