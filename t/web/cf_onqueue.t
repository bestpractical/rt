use strict;
use warnings;

use RT::Test tests => 14;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

diag "Create a queue CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Freeform-1',
            LookupType => 'RT::Queue',
            Name => 'QueueCFTest',
            Description => 'QueueCFTest',
        },
    );
    $m->content_contains('Object created', 'CF QueueCFTest created' );
}

diag "Apply the new CF globally";
{
    $m->follow_link( text => 'Global' );
    $m->title_is(q!Admin/Global configuration!, 'global configuration screen');
    $m->follow_link( url_regex => qr!Admin/Global/CustomFields/index! );
    $m->title_is(q/Global custom field configuration/, 'global custom field configuration screen');
    $m->follow_link( url => 'Queues.html' );
    $m->title_is(q/Edit Custom Fields for all queues/, 'global custom field for all queues configuration screen');
    $m->content_contains('QueueCFTest', 'CF QueueCFTest displayed on page' );

    $m->form_name('EditCustomFields');
    $m->tick( AddCustomField => 2 );
    $m->click('UpdateCFs');

    $m->content_contains("Globally added custom field QueueCFTest", 'CF QueueCFTest enabled globally' );
}

diag "Edit the CF value for default queue";
{
    $m->follow_link( url => '/Admin/Queues/' );
    $m->title_is(q/Admin queues/, 'queues configuration screen');
    $m->follow_link( text => "1" );
    $m->title_is(q/Configuration for queue General/, 'default queue configuration screen');
    $m->content_contains('QueueCFTest', 'CF QueueCFTest displayed on default queue' );
    $m->submit_form(
        form_number => 3,
        # The following doesn't want to works :(
        #with_fields => { 'Object-RT::Queue-1-CustomField-2-Value' },
        fields => {
            'Object-RT::Queue-1-CustomField-2-Value' => 'QueueCFTest content',
        },
    );
    $m->content_contains('QueueCFTest QueueCFTest content added', 'Content filed in CF QueueCFTest for default queue' );

}


__END__
