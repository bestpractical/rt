use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $select_cf = RT::CustomField->new(RT->SystemUser);
$select_cf->Create(Name => 'Select CF', Type => 'Select', MaxValues => 1);
$select_cf->AddValue(Name => 'First Value', SortOrder => 0);
$select_cf->AddValue(Name => 'Second Value', SortOrder => 1);
$select_cf->AddValue(Name => 'Third Value', SortOrder => 2);
my $select_cf_id = $select_cf->id;
my $select_cf_values = $select_cf->Values->ItemsArrayRef;

my $basedon_cf = RT::CustomField->new(RT->SystemUser);
$basedon_cf->Create(Name => 'SubSelect CF', Type => 'Select', MaxValues => 1, BasedOn => $select_cf->id);
$basedon_cf->AddValue(Name => 'With First Value', Category => $select_cf_values->[0]->Name, SortOder => 0);
$basedon_cf->AddValue(Name => 'With No Value', SortOder => 0);
my $basedon_cf_id = $basedon_cf->id;
my $basedon_cf_values = $basedon_cf->Values->ItemsArrayRef;

# Right test - retrieve all values without SeeCustomField
{
    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id/values",
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

$user->PrincipalObj->GrantRight(Right => 'SeeCustomField');

# Retrieve customfield's hypermedia link for customfieldvalues
{
    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    my $links = $content->{_hyperlinks};
    my @cfvs_links = grep { $_->{ref} eq 'customfieldvalues' } @$links;
    is(scalar(@cfvs_links), 1);
    like($cfvs_links[0]->{_url}, qr{$rest_base_path/customfield/$select_cf_id/values$});
}

# No customfieldvalues hypermedia link for non-select customfield
{
    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Create(Name => 'Freeform CF', Type => 'Freeform', MaxValues => 1, Queue => 'General');
    my $freeform_cf_id = $freeform_cf->id;

    my $res = $mech->get("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    my $links = $content->{_hyperlinks};
    my @cfvs_links = grep { $_->{ref} eq 'customfieldvalues' } @$links;
    is(scalar(@cfvs_links), 0);
}

# Retrieve all values
{

    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id/values",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 3);
    my $items = $content->{items};
    is(scalar(@$items), 3);

    for (my $i=0; $i < scalar @$items; $i++) {
        my $cf_value_id = $select_cf_values->[$i]->id;
        is($items->[$i]->{type}, 'customfieldvalue');
        is($items->[$i]->{id}, $cf_value_id);
        is($items->[$i]->{name}, $select_cf_values->[$i]->Name);
        like($items->[$i]->{_url}, qr{$rest_base_path/customfield/$select_cf_id/value/$cf_value_id$});
    }
}

# Right test - udpate a value without AdminCustomFieldValues nor AdminCustomField
{
    my $payload = {
        Name => 'Third and Last Value',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/$select_cf_id/value/" . $select_cf_values->[-1]->id,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    $select_cf_values = $select_cf->Values->ItemsArrayRef;
    is($select_cf_values->[-1]->Name, 'Third Value');
}

# Right test - udpate a value without AdminCustomFieldValues but with AdminCustomField
{
    $user->PrincipalObj->GrantRight(Right => 'AdminCustomField');

    my $payload = {
        Name => 'Third and Last Value',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/$select_cf_id/value/" . $select_cf_values->[-1]->id,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $select_cf_values = $select_cf->Values->ItemsArrayRef;
    is($select_cf_values->[-1]->Name, 'Third and Last Value');
}

# Right test - udpate a value without AdminCustomField but with AdminCustomFieldValues
{
    $user->PrincipalObj->RevokeRight(Right => 'AdminCustomField');
    $user->PrincipalObj->GrantRight(Right => 'AdminCustomFieldValues', Object => $select_cf);
    $user->PrincipalObj->GrantRight(Right => 'AdminCustomFieldValues', Object => $basedon_cf);

    my $payload = {
        Name => 'Third and Last but NOT Least Value',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/$select_cf_id/value/" . $select_cf_values->[-1]->id,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $select_cf_values = $select_cf->Values->ItemsArrayRef;
    is($select_cf_values->[-1]->Name, 'Third and Last but NOT Least Value');
}

# Add a value
{
    my $payload = {
        Name      => 'Fourth Value',
        SortOrder => 3,
    };
    my $res = $mech->post_json("$rest_base_path/customfield/$select_cf_id/value",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);

    $select_cf_values = $select_cf->Values->ItemsArrayRef;
    is(scalar(@$select_cf_values), 4);
    is($select_cf_values->[-1]->Name, 'Fourth Value');
}

# Retrieve a value
{
    my $cfv = $select_cf_values->[-2];
    my $cfv_id = $cfv->id;
    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id/value/$cfv_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    foreach my $field (qw/id Name Description SortOrder Category/) {
        is($content->{$field}, $cfv->$field);
    }

    ok(exists $content->{$_}, "got $_") for qw/Created Creator LastUpdated LastUpdatedBy/;

    is($content->{CustomField}->{id}, $select_cf_id);

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);

    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $cfv_id);
    is($links->[0]{type}, 'customfieldvalue');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$select_cf_id/customfieldvalue/$cfv_id$});

    is($links->[1]{ref}, 'customfield');
    is($links->[1]{id}, $select_cf_id);
    is($links->[1]{type}, 'customfield');
    like($links->[1]{_url}, qr{$rest_base_path/customfield/$select_cf_id$});
}

# Retrieve all values filtered by category
{
    my $payload = [
        {
            field => 'Category',
            value => $select_cf_values->[0]->Name,
        }
    ];
    my $res = $mech->post_json("$rest_base_path/customfield/$basedon_cf_id/values",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 1);
    is($content->{count}, 1);
    my $items = $content->{items};
    is(scalar(@$items), 1);

    for (my $i=0; $i < scalar @$items; $i++) {
        my $cf_value_id = $basedon_cf_values->[$i]->id;
        is($items->[$i]->{type}, 'customfieldvalue');
        is($items->[$i]->{id}, $cf_value_id);
        is($items->[$i]->{name}, $basedon_cf_values->[$i]->Name);
        like($items->[$i]->{_url}, qr{$rest_base_path/customfield/$basedon_cf_id/value/$cf_value_id$});
    }
}

# Delete a value
{
    my $res = $mech->delete("$rest_base_path/customfield/$select_cf_id/value/" . $select_cf_values->[-1]->id,
        'Authorization' => $auth,
    );
    is($res->code, 204);

    $select_cf_values = $select_cf->Values->ItemsArrayRef;
    is(scalar(@$select_cf_values), 3);
    is($select_cf_values->[-1]->Name, 'Third and Last but NOT Least Value');
}

done_testing;
