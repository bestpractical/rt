use strict;
use warnings;

use RT::Test tests => 8;

use constant VALUES_CLASS => 'RT::CustomFieldValues::Groups';
RT->Config->Set(CustomFieldValuesSources => VALUES_CLASS);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $cf_name = 'test values class';

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'Select-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_contains('Object created', 'created Select-1' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "change to external values class";
{
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields    => { ValuesClass => 'RT::CustomFieldValues::Groups', },
        button    => 'Update',
    );
    $m->content_contains(
        "Field values source changed from &#39;RT::CustomFieldValues&#39; to &#39;RT::CustomFieldValues::Groups&#39;",
        'changed to external values class' );
}

diag "change to internal values class";
{
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields    => { ValuesClass => 'RT::CustomFieldValues', },
        button    => 'Update',
    );
    $m->content_contains(
        "Field values source changed from &#39;RT::CustomFieldValues::Groups&#39; to &#39;RT::CustomFieldValues&#39;",
        'changed to internal values class' );
}

