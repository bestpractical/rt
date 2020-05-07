use strict;
use warnings;
use lib 't/lib';
use RT::Test::REST2 tests => undef;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $select_cf = RT::CustomField->new(RT->SystemUser);
$select_cf->Create(Name => 'Select CF', Type => 'Select', MaxValues => 1, Queue => 'General');
$select_cf->AddValue(Name => 'First Value', SortOder => 0);
$select_cf->AddValue(Name => 'Second Value', SortOrder => 1);
$select_cf->AddValue(Name => 'Third Value', SortOrder => 2);
my $select_cf_id = $select_cf->id;
my $select_cf_values = $select_cf->Values->ItemsArrayRef;

my $basedon_cf = RT::CustomField->new(RT->SystemUser);
$basedon_cf->Create(Name => 'SubSelect CF', Type => 'Select', MaxValues => 1, Queue => 'General', BasedOn => $select_cf->id);
$basedon_cf->AddValue(Name => 'With First Value', Category => $select_cf_values->[0]->Name, SortOder => 0);
$basedon_cf->AddValue(Name => 'With No Value', SortOder => 0);
my $basedon_cf_id = $basedon_cf->id;
my $basedon_cf_values = $basedon_cf->Values->ItemsArrayRef;

my $freeform_cf;
my $freeform_cf_id;

# Right test - create customfield without SeeCustomField nor AdminCustomField
{
    my $payload = {
        Name      => 'Freeform CF',
        Type      => 'Freeform',
        MaxValues => 1,
    };
    my $res = $mech->post_json("$rest_base_path/customfield",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    my ($ok, $msg) = $freeform_cf->Load('Freeform CF');
    is($freeform_cf->id, undef);
    ok(!$ok);
    is($msg, 'Not found');
}

# Customfield create
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );
    my $payload = {
        Name       => 'Freeform CF',
        Type       => 'Freeform',
        LookupType => 'RT::Queue-RT::Ticket',
        MaxValues  => 1,
    };
    my $res = $mech->post_json("$rest_base_path/customfield",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);

    $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    $freeform_cf_id = $freeform_cf->id;
    is($freeform_cf->id, 4);
    is($freeform_cf->Description, '');
}


# Right test - search all tickets customfields without SeeCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'SeeCustomField' );

    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 0);
    is_deeply($content->{items}, []);
}

# search all tickets customfields
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 3);
    my $items = $content->{items};
    is(scalar(@$items), 3);

    is($items->[0]->{type}, 'customfield');
    is($items->[0]->{id}, $freeform_cf->id);
    like($items->[0]->{_url}, qr{$rest_base_path/customfield/$freeform_cf_id$});

    is($items->[1]->{type}, 'customfield');
    is($items->[1]->{id}, $select_cf->id);
    like($items->[1]->{_url}, qr{$rest_base_path/customfield/$select_cf_id$});

    is($items->[2]->{type}, 'customfield');
    is($items->[2]->{id}, $basedon_cf->id);
    like($items->[2]->{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});
}

# Freeform CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $freeform_cf_id);
    is($content->{Name}, $freeform_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Freeform');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $freeform_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$freeform_cf_id$});
}

# Select CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$select_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $select_cf_id);
    is($content->{Name}, $select_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $select_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$select_cf_id$});

    is($links->[1]{ref}, 'customfieldvalues');
    like($links->[1]{_url}, qr{$rest_base_path/customfield/$select_cf_id/values$});

    my $values = $content->{Values};
    is_deeply($values, ['First Value', 'Second Value', 'Third Value']);
}

# BasedOn CustomField display
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});

    is($links->[1]{ref}, 'customfieldvalues');
    like($links->[1]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id/values$});

    my $values = $content->{Values};
    is_deeply($values, ['With First Value', 'With No Value']);
}

# BasedOn CustomField display with category filter
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id?category=First%20Value",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});

    is($links->[1]{ref}, 'customfieldvalues');
    like($links->[1]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id/values$});

    my $values = $content->{Values};
    is_deeply($values, ['With First Value']);
}

# BasedOn CustomField display with null category filter
{
    my $res = $mech->get("$rest_base_path/customfield/$basedon_cf_id?category=",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $basedon_cf_id);
    is($content->{Name}, $basedon_cf->Name);
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Select');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 2);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $basedon_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id$});


    is($links->[1]{ref}, 'customfieldvalues');
    like($links->[1]{_url}, qr{$rest_base_path/customfield/$basedon_cf_id/values$});

    my $values = $content->{Values};
    is_deeply($values, ['With No Value']);
}

# Display customfield
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->get("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is($content->{id}, $freeform_cf_id);
    is($content->{Name}, 'Freeform CF');
    is($content->{Description}, '');
    is($content->{LookupType}, 'RT::Queue-RT::Ticket');
    is($content->{Type}, 'Freeform');
    is($content->{MaxValues}, 1);
    is($content->{Disabled}, 0);

    my @fields = qw(SortOrder Pattern Created Creator LastUpdated LastUpdatedBy);
    push @fields, qw(UniqueValues EntryHint) if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
    ok(exists $content->{$_}, "got $_") for @fields;

    my $links = $content->{_hyperlinks};
    is(scalar @$links, 1);
    is($links->[0]{ref}, 'self');
    is($links->[0]{id}, $freeform_cf_id);
    is($links->[0]{type}, 'customfield');
    like($links->[0]{_url}, qr{$rest_base_path/customfield/$freeform_cf_id$});
}

# Right test - update customfield without AdminCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'AdminCustomField' );

    my $payload = {
        Description  => 'This is a CF for testing REST CRUD on CFs',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/$freeform_cf_id",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');
}

# Update customfield
{
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );

    my $payload = {
        Description  => 'This is a CF for testing REST CRUD on CFs',
    };
    my $res = $mech->put_json("$rest_base_path/customfield/$freeform_cf_id",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->id, $freeform_cf_id);
    is($freeform_cf->Description, 'This is a CF for testing REST CRUD on CFs');
}

# Right test - delete customfield without AdminCustomField
{
    $user->PrincipalObj->RevokeRight( Right => 'AdminCustomField' );

    my $res = $mech->delete("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 403);
    is($res->message, 'Forbidden');

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->Disabled, 0);
}

# Delete customfield
{
    $user->PrincipalObj->GrantRight( Right => 'AdminCustomField' );

    my $res = $mech->delete("$rest_base_path/customfield/$freeform_cf_id",
        'Authorization' => $auth,
    );
    is($res->code, 204);

    my $freeform_cf = RT::CustomField->new(RT->SystemUser);
    $freeform_cf->Load('Freeform CF');
    is($freeform_cf->Disabled, 1);
}

done_testing;
