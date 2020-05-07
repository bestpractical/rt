use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

BEGIN {
    plan skip_all => 'RT 4.4 required'
        unless RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;
}

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $catalog = RT::Catalog->new( RT->SystemUser );
$catalog->Load('General assets');
$catalog->Create(Name => 'General assets') if !$catalog->Id;
ok($catalog->Id, "General assets catalog");

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', LookupType => RT::Asset->CustomFieldLookupType);
ok($ok, $msg);
my $single_cf_id = $single_cf->Id;

($ok, $msg) = $single_cf->AddToObject($catalog);
ok($ok, $msg);

my $multi_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $multi_cf->Create( Name => 'Multi', Type => 'FreeformMultiple', LookupType => RT::Asset->CustomFieldLookupType);
ok($ok, $msg);
my $multi_cf_id = $multi_cf->Id;

($ok, $msg) = $multi_cf->AddToObject($catalog);
ok($ok, $msg);

# Asset Creation with no ModifyCustomField
my ($asset_url, $asset_id);
{
    my $payload = {
        Name    => 'Asset creation using REST',
        Catalog => 'General assets',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
    };

    # Rights Test - No CreateAsset
    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);
    my $content = $mech->json_response;
    is($content->{message}, 'Permission Denied', "can't create Asset with custom fields you can't set");

    # Rights Test - With CreateAsset
    $user->PrincipalObj->GrantRight( Right => 'CreateAsset' );
    $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 400);

    delete $payload->{CustomFields};

    $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($asset_url = $res->header('location'));
    ok(($asset_id) = $asset_url =~ qr[/asset/(\d+)]);
}

# Asset Display
{
    # Rights Test - No ShowAsset
    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowAsset but no SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ShowAsset' );

    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $asset_id);
    is($content->{Status}, 'new');
    is($content->{Name}, 'Asset creation using REST');
    is_deeply($content->{'CustomFields'}, [], 'Asset custom field not present');
    is_deeply([grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }], [], 'No CF hypermedia');
}

my $no_asset_cf_values = bag(
  { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
  { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
);

# Rights Test - With ShowAsset and SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField');

    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $asset_id);
    is($content->{Status}, 'new');
    is($content->{Name}, 'Asset creation using REST');
    cmp_deeply($content->{CustomFields}, $no_asset_cf_values, 'No asset custom field values');


    cmp_deeply(
        [grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }],
        [{
            ref => 'customfield',
            id  => $single_cf_id,
            name => 'Single',
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$single_cf_id$]),
        }, {
            ref => 'customfield',
            id  => $multi_cf_id,
            name => 'Multi',
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$multi_cf_id$]),
        }],
        'Two CF hypermedia',
    );

    my ($single_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $single_cf_id } @{ $content->{'_hyperlinks'} };
    my ($multi_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $multi_cf_id } @{ $content->{'_hyperlinks'} };

    $res = $mech->get($single_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $single_cf_id,
        Disabled   => 0,
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 1,
	Name       => 'Single',
	Type       => 'Freeform',
    }), 'single cf');

    $res = $mech->get($multi_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $multi_cf_id,
        Disabled   => 0,
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 0,
	Name       => 'Multi',
	Type       => 'Freeform',
    }), 'multi cf');
}

# Asset Update without ModifyCustomField
{
    my $payload = {
        Name     => 'Asset update using REST',
        Status   => 'allocated',
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };

    # Rights Test - No ModifyAsset
    my $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Asset Asset creation using REST: Permission Denied', 'Asset Asset creation using REST: Permission Denied', 'Could not add new custom field value: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyAsset' );

    $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Asset Asset update using REST: Name changed from 'Asset creation using REST' to 'Asset update using REST'", "Asset Asset update using REST: Status changed from 'new' to 'allocated'", 'Could not add new custom field value: Permission Denied']);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Name}, 'Asset update using REST');
    is($content->{Status}, 'allocated');
    cmp_deeply($content->{CustomFields}, $no_asset_cf_values, 'No update to CF');
}

# Asset Update with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );
    my $payload = {
        Name  => 'More updates using REST',
        Status => 'in-use',
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };
    my $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Asset More updates using REST: Name changed from 'Asset update using REST' to 'More updates using REST'", "Asset More updates using REST: Status changed from 'allocated' to 'in-use'", 'Single Modified CF added']);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $modified_asset_cf_values = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified CF'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{Name}, 'More updates using REST');
    is($content->{Status}, 'in-use');
    cmp_deeply($content->{CustomFields}, $modified_asset_cf_values, 'New CF value');

    # make sure changing the CF doesn't add a second OCFV
    $payload->{CustomFields}{$single_cf_id} = 'Modified Again';
    $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ['Single Modified CF changed to Modified Again']);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $modified_asset_cf_values = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified Again'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_asset_cf_values, 'New CF value');

    # stop changing the CF, change something else, make sure CF sticks around
    delete $payload->{CustomFields}{$single_cf_id};
    $payload->{Name} = 'No CF change';
    $res = $mech->put_json($asset_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Asset No CF change: Name changed from 'More updates using REST' to 'No CF change'"]);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_asset_cf_values, 'Same CF value');
}

# Asset Creation with ModifyCustomField
{
    my $payload = {
        Name    => 'Asset creation using REST',
        Catalog => 'General assets',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
    };

    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($asset_url = $res->header('location'));
    ok(($asset_id) = $asset_url =~ qr[/asset/(\d+)]);
}

# Rights Test - With ShowAsset and SeeCustomField
{
    my $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $asset_cf_values = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Hello world!'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{id}, $asset_id);
    is($content->{Status}, 'new');
    is($content->{Name}, 'Asset creation using REST');
    cmp_deeply($content->{'CustomFields'}, $asset_cf_values, 'Asset custom field');
}

# Asset Creation for multi-value CF
for my $value (
    'scalar',
    ['array reference'],
    ['multiple', 'values'],
) {
    my $payload = {
        Name => 'Multi-value CF',
        Catalog => 'General assets',
        CustomFields => {
            $multi_cf_id => $value,
        },
    };

    my $res = $mech->post_json("$rest_base_path/asset",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($asset_url = $res->header('location'));
    ok(($asset_id) = $asset_url =~ qr[/asset/(\d+)]);

    $res = $mech->get($asset_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $asset_id);
    is($content->{Status}, 'new');
    is($content->{Name}, 'Multi-value CF');

    my $output = ref($value) ? $value : [$value]; # scalar input comes out as array reference
    my $asset_cf_values = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => $output },
    );

    cmp_deeply($content->{'CustomFields'}, $asset_cf_values, 'Asset custom field');
}

{
    sub modify_multi_ok {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $input = shift;
        my $messages = shift;
        my $output = shift;
        my $name = shift;

        my $payload = {
            CustomFields => {
                $multi_cf_id => $input,
            },
        };
        my $res = $mech->put_json($asset_url,
            $payload,
            'Authorization' => $auth,
        );
        is($res->code, 200);
        is_deeply($mech->json_response, $messages);

        $res = $mech->get($asset_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        my $content = $mech->json_response;
        my $values;
        for my $cf (@{ $content->{CustomFields} }) {
            next unless $cf->{id} == $multi_cf_id;

            $values = [ sort @{ $cf->{values} } ];
        }
        cmp_deeply($values, $output, $name || 'New CF value');
    }

    # starting point: ['multiple', 'values'],
    modify_multi_ok(['multiple', 'values'], [], ['multiple', 'values'], 'no change');
    modify_multi_ok(['multiple', 'values', 'new'], ['new added as a value for Multi'], ['multiple', 'new', 'values'], 'added "new"');
    modify_multi_ok(['multiple', 'new'], ['values is no longer a value for custom field Multi'], ['multiple', 'new'], 'removed "values"');
    modify_multi_ok('replace all', ['replace all added as a value for Multi', 'multiple is no longer a value for custom field Multi', 'new is no longer a value for custom field Multi'], ['replace all'], 'replaced all values');
    modify_multi_ok([], ['replace all is no longer a value for custom field Multi'], [], 'removed all values');

    modify_multi_ok(['foo', 'foo', 'bar'], ['foo added as a value for Multi', undef, 'bar added as a value for Multi'], ['bar', 'foo'], 'multiple values with the same name');
    modify_multi_ok(['foo', 'bar'], [], ['bar', 'foo'], 'multiple values with the same name');
    modify_multi_ok(['bar'], ['foo is no longer a value for custom field Multi'], ['bar'], 'multiple values with the same name');
    modify_multi_ok(['bar', 'bar', 'bar'], [undef, undef], ['bar'], 'multiple values with the same name');
}

done_testing;

