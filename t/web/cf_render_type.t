use strict;
use warnings;

use RT::Test tests => 8;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $cf_name = 'test render type';

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'Freeform-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_contains('Object created', 'created Freeform-1' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "change to Select type";
{
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields    => { TypeComposite => 'Select-1', },
        button    => 'Update',
    );
    $m->content_contains(
        "Type changed from &#39;Enter one value&#39; to &#39;Select one value&#39;",
        'changed to Select-1' );
}

diag "let's save it again";
{
    $m->submit_form(
        form_name => "ModifyCustomField",
        button    => 'Update',
    );
    $m->content_lacks( "Render Type changed from &#39;1&#39; to &#39;Select box&#39;",
        'no buggy RenderType change msg' );
}


