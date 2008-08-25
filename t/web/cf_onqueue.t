#!/usr/bin/perl -w
use strict;

use Test::More tests => 14;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

diag "Create a queue CF" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is(q/RT Administration/, 'admin screen');
    $m->follow_link( text => 'Custom Fields' );
    $m->title_is(q/Select a Custom Field/, 'admin-cf screen');
    $m->follow_link( text => 'Create' );
    $m->submit_form(
        form_name => 'modify_custom_field',
        fields => {
            type_composite =>  'Freeform-1',
            lookup_type => 'RT::Model::Queue',
            name =>  'QueueCFTest',
            description =>  'QueueCFTest',
        },
    );
    $m->content_like( qr/Object created/, 'CF QueueCFTest created' );
}

diag "Apply the new CF globally" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Global' );
    $m->title_is(q!Admin/Global configuration!, 'global configuration screen');
    $m->follow_link( url_regex => qr!Admin/Global/CustomFields/index! );
    $m->title_is(q/Global custom field configuration/, 'global custom field configuration screen');
    $m->follow_link( url => 'Queues.html' );
    $m->title_is(q/Edit Custom Fields for all queues/, 'global custom field for all queues configuration screen');
    $m->content_like( qr/QueueCFTest/, 'CF QueueCFTest displayed on page' );
    $m->submit_form(
        form_name => 'edit_custom_fields',
        fields => {
            'object--CF-1' => '1',
        },
    );
    $m->content_like( qr/Object created/, 'CF QueueCFTest enabled globally' );
}

diag "Edit the CF value for default queue" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( url => '/Admin/Queues/' );
    $m->title_is(q/Admin queues/, 'queues configuration screen');
    $m->follow_link( text => "1" );
    $m->title_is(q/Editing Configuration for queue General/, 'default queue configuration screen');
    $m->content_like( qr/QueueCFTest/, 'CF QueueCFTest displayed on default queue' );
    $m->submit_form(
        form_number => 3,
        # The following doesn't want to works :(
        #with_fields => { 'object-RT::Model::Queue-1-CustomField-1-value' },
        fields => {
            'object-RT::Model::Queue-1-CustomField-1-value' => 'QueueCFTest content',
        },
    );
    $m->content_like( qr/QueueCFTest QueueCFTest content added/, 'Content filed in CF QueueCFTest for default queue' );

}


__END__
