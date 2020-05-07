use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ($ok, $msg) = $single_cf->Create( Name => 'Freeform', Type => 'FreeformSingle', LookupType => RT::User->CustomFieldLookupType );
ok($ok, $msg);
my $single_cf_id = $single_cf->Id();
my $ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $single_cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );

my $multi_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $multi_cf->Create( Name => 'Multi', Type => 'FreeformMultiple', LookupType => RT::User->CustomFieldLookupType );
ok($ok, $msg);
my $multi_cf_id = $multi_cf->Id();
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $multi_cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );

# User Creation with no AdminUsers
my ($user_url, $user_id);
{
    my $payload = {
        Name         => 'user1',
        EmailAddress => 'user1@example.com',
        CustomFields => {
            $single_cf->Id => 'Hello world!',
        },
    };

    # Rights Test - No AdminUsers
    my $res = $mech->post_json("$rest_base_path/user",
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "this should return 403";
        is($res->code, 403);
    }

    # Rights Test - With AdminUsers
    $user->PrincipalObj->GrantRight( Right => 'AdminUsers' );
    $res = $mech->post_json("$rest_base_path/user",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($user_url = $res->header('location'));
    ok(($user_id) = $user_url =~ qr[/user/(\d+)]);
}

# Rights Test - no SeeCustomField
{
    my $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $user_id);
    is($content->{EmailAddress}, 'user1@example.com');
    is($content->{Name}, 'user1');
    is_deeply($content->{'CustomFields'}, [], 'User custom field not present');

    # can fetch user by name too
    $res = $mech->get("$rest_base_path/user/user1",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    is_deeply($mech->json_response, $content, 'requesting user by name is same as user by id');
}

my $no_user_cf_values = bag(
  { name => 'Freeform', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
  { name => 'Multi',    id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
);

# Rights Test - With SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField');

    my $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $user_id);
    is($content->{EmailAddress}, 'user1@example.com');
    is($content->{Name}, 'user1');
    cmp_deeply($content->{'CustomFields'}, $no_user_cf_values, 'User custom field not present');
}

# User Update without ModifyCustomField
{
    my $payload = {
        Name  => 'User1',
        CustomFields => {
            $single_cf->Id => 'Modified CF',
        },
    };

    my $res = $mech->put_json($user_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["User User1: Name changed from 'user1' to 'User1'", 'Could not add new custom field value: Permission Denied']);

    $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $user_id);
    is($content->{EmailAddress}, 'user1@example.com');
    is($content->{Name}, 'User1');
    cmp_deeply($content->{'CustomFields'}, $no_user_cf_values, 'User custom field not present');
}

# User Update with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );
    my $payload = {
        EmailAddress  => 'user1+rt@example.com',
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };
    my $res = $mech->put_json($user_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["User User1: EmailAddress changed from 'user1\@example.com' to 'user1+rt\@example.com'", 'Freeform Modified CF added']);

    $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{EmailAddress}, 'user1+rt@example.com');

    my $set_user_cf_values = bag(
        { name => 'Freeform', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified CF'] },
        { name => 'Multi',    id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );
    cmp_deeply($content->{'CustomFields'}, $set_user_cf_values, 'New CF value');

    # make sure changing the CF doesn't add a second OCFV
    $payload->{CustomFields}{$single_cf->Id} = 'Modified Again';
    $res = $mech->put_json($user_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ['Freeform Modified CF changed to Modified Again']);

    $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;

    $set_user_cf_values = bag(
        { name => 'Freeform', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified Again'] },
        { name => 'Multi',    id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );
    cmp_deeply($content->{'CustomFields'}, $set_user_cf_values, 'New CF value');

    # stop changing the CF, change something else, make sure CF sticks around
    delete $payload->{CustomFields}{$single_cf->Id};
    $payload->{EmailAddress} = 'user1+rt.test@example.com';
    $res = $mech->put_json($user_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["User User1: EmailAddress changed from 'user1+rt\@example.com' to 'user1+rt.test\@example.com'"]);

    $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    cmp_deeply($content->{'CustomFields'}, $set_user_cf_values, 'Same CF value');
}

# User Creation with ModifyCustomField
{
    my $payload = {
        Name => 'user2',
        CustomFields => {
            $single_cf->Id => 'Hello world!',
        },
    };

    my $res = $mech->post_json("$rest_base_path/user",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($user_url = $res->header('location'));
    ok(($user_id) = $user_url =~ qr[/user/(\d+)]);
}

# Rights Test - With SeeCustomField
{
    my $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $user_id);
    is($content->{Name}, 'user2');

    my $set_user_cf_values = bag(
        { name => 'Freeform', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Hello world!'] },
        { name => 'Multi',    id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );
    cmp_deeply($content->{'CustomFields'}, $set_user_cf_values, 'User custom field');
}

# User Creation for multi-value CF
for my $value (
    'scalar',
    ['array reference'],
    ['multiple', 'values'],
) {
    my $payload = {
        Name => "user-$value",
        CustomFields => {
            $multi_cf->Id => $value,
        },
    };

    my $res = $mech->post_json("$rest_base_path/user",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($user_url = $res->header('location'));
    ok(($user_id) = $user_url =~ qr[/user/(\d+)]);

    $res = $mech->get($user_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $user_id);
    my $output = ref($value) ? $value : [$value]; # scalar input comes out as array reference
    my $set_user_cf_values = bag(
        { name => 'Freeform', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',    id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => $output },
    );
    cmp_deeply($content->{'CustomFields'}, $set_user_cf_values, 'User custom field');
}

done_testing;

