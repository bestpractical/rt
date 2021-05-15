use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

my $class = RT::Class->new( RT->SystemUser );
$class->Load('General');
$class->Create( Name => 'General' ) if !$class->Id;
ok( $class->Id, "General class" );

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ( $ok, $msg ) = $single_cf->Load('Content');
ok( $ok, $msg );
my $single_cf_id = $single_cf->Id;

( $ok, $msg ) = $single_cf->AddToObject($class);
ok( $ok, $msg );

my $multi_cf = RT::CustomField->new( RT->SystemUser );
( $ok, $msg )
    = $multi_cf->Create( Name => 'Multi', Type => 'FreeformMultiple',
    LookupType => RT::Article->CustomFieldLookupType );
ok( $ok, $msg );
my $multi_cf_id = $multi_cf->Id;

( $ok, $msg ) = $multi_cf->AddToObject($class);
ok( $ok, $msg );

# Article Creation with no ModifyCustomField
my ( $article_url, $article_id );
{
    my $payload = {
        Name         => 'Article creation using REST',
        Class        => 'General',
        CustomFields => { $single_cf_id => 'Hello world!', },
    };

    # Rights Test - No CreateArticle
    my $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 403 );
    my $content = $mech->json_response;
    is( $content->{message}, 'Permission Denied', "can't create Article with custom fields you can't set" );

    # Rights Test - With CreateArticle
    $user->PrincipalObj->GrantRight( Right => 'CreateArticle' );

    $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 400 );

    delete $payload->{CustomFields};

    $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( $article_url = $res->header('location') );
    ok( ($article_id) = $article_url =~ qr[/article/(\d+)] );
}

# Article Display
{
    # Rights Test - No ShowArticle
    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 403 );
}

# Rights Test - With ShowArticle but no SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ShowArticle' );

    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},   $article_id );
    is( $content->{Name}, 'Article creation using REST' );
    is_deeply( $content->{'CustomFields'}, [], 'Article custom field not present' );
    is_deeply( [ grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} } ], [], 'No CF hypermedia' );
}

my $no_article_cf_values = bag(
    { name => 'Content', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
    { name => 'Multi',   id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
);

# Rights Test - With ShowArticle and SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},   $article_id );
    is( $content->{Name}, 'Article creation using REST' );
    cmp_deeply( $content->{CustomFields}, $no_article_cf_values, 'No article custom field values' );

    cmp_deeply(
        [ grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} } ],
        [   {   ref  => 'customfield',
                id   => $single_cf_id,
                name => 'Content',
                type => 'customfield',
                _url => re(qr[$rest_base_path/customfield/$single_cf_id$]),
            },
            {   ref  => 'customfield',
                id   => $multi_cf_id,
                name => 'Multi',
                type => 'customfield',
                _url => re(qr[$rest_base_path/customfield/$multi_cf_id$]),
            }
        ],
        'Two CF hypermedia',
    );

    my ($single_url)
        = map { $_->{_url} }
        grep { $_->{ref} eq 'customfield' && $_->{id} == $single_cf_id } @{ $content->{'_hyperlinks'} };
    my ($multi_url)
        = map { $_->{_url} }
        grep { $_->{ref} eq 'customfield' && $_->{id} == $multi_cf_id } @{ $content->{'_hyperlinks'} };

    $res = $mech->get( $single_url, 'Authorization' => $auth, );
    is( $res->code, 200 );
    cmp_deeply(
        $mech->json_response,
        superhashof(
            {   id         => $single_cf_id,
                Disabled   => 0,
                LookupType => RT::Article->CustomFieldLookupType,
                MaxValues  => 1,
                Name       => 'Content',
                Type       => 'Text',
            }
        ),
        'single cf'
    );

    $res = $mech->get( $multi_url, 'Authorization' => $auth, );
    is( $res->code, 200 );
    cmp_deeply(
        $mech->json_response,
        superhashof(
            {   id         => $multi_cf_id,
                Disabled   => 0,
                LookupType => RT::Article->CustomFieldLookupType,
                MaxValues  => 0,
                Name       => 'Multi',
                Type       => 'Freeform',
            }
        ),
        'multi cf'
    );
}

# Article Update without ModifyCustomField
{
    my $payload = {
        Name         => 'Article update using REST',
        CustomFields => { $single_cf_id => 'Modified CF', },
    };

    # Rights Test - No ModifyArticle
    my $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is( $res->code, 403 );
    }
    is_deeply(
        $mech->json_response,
        [   'Article Article creation using REST: Permission Denied',
            'Could not add new custom field value: Permission Denied'
        ]
    );

    $user->PrincipalObj->GrantRight( Right => 'ModifyArticle' );

    $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply(
        $mech->json_response,
        [   'Article Article update using REST: Name changed from "Article creation using REST" to "Article update using REST"',
            'Could not add new custom field value: Permission Denied'
        ]
    );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{Name}, 'Article update using REST' );
    cmp_deeply( $content->{CustomFields}, $no_article_cf_values, 'No update to CF' );
}

# Article Update with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );
    my $payload = {
        Name         => 'More updates using REST',
        CustomFields => { $single_cf_id => 'Modified CF', },
    };
    my $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply(
        $mech->json_response,
        [   'Article More updates using REST: Name changed from "Article update using REST" to "More updates using REST"',
            'Content Modified CF added'
        ]
    );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $modified_article_cf_values = bag(
        { name => 'Content', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified CF'] },
        { name => 'Multi',   id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is( $content->{Name}, 'More updates using REST' );
    cmp_deeply( $content->{CustomFields}, $modified_article_cf_values, 'New CF value' );

    # make sure changing the CF doesn't add a second OCFV
    $payload->{CustomFields}{$single_cf_id} = 'Modified Again';
    $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply( $mech->json_response, ['Content Modified CF changed to Modified Again'] );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    $modified_article_cf_values = bag(
        {   name   => 'Content',
            id     => $single_cf_id,
            type   => 'customfield',
            _url   => ignore(),
            values => ['Modified Again']
        },
        { name => 'Multi', id => $multi_cf_id, type => 'customfield', _url => ignore(), values => [] },
    );

    $content = $mech->json_response;
    cmp_deeply( $content->{CustomFields}, $modified_article_cf_values, 'New CF value' );

    # stop changing the CF, change something else, make sure CF sticks around
    delete $payload->{CustomFields}{$single_cf_id};
    $payload->{Name} = 'No CF change';
    $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply( $mech->json_response,
        ['Article No CF change: Name changed from "More updates using REST" to "No CF change"'] );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    $content = $mech->json_response;
    cmp_deeply( $content->{CustomFields}, $modified_article_cf_values, 'Same CF value' );
}

# Article Creation with ModifyCustomField
{
    my $payload = {
        Name         => 'Article creation using REST',
        Class        => 'General',
        CustomFields => { $single_cf_id => 'Hello world!', },
    };

    my $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( $article_url = $res->header('location') );
    ok( ($article_id) = $article_url =~ qr[/article/(\d+)] );
}

# Rights Test - With ShowArticle and SeeCustomField
{
    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $article_cf_values = bag(
        { name => 'Content', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Hello world!'] },
        { name => 'Multi',   id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is( $content->{id},   $article_id );
    is( $content->{Name}, 'Article creation using REST' );
    cmp_deeply( $content->{'CustomFields'}, $article_cf_values, 'Article custom field' );
}

# Article Creation for multi-value CF
my $i = 1;
for my $value ( 'scalar', ['array reference'], [ 'multiple', 'values' ], ) {
    my $payload = {
        Name         => 'Multi-value CF ' . $i,
        Class        => 'General',
        CustomFields => { $multi_cf_id => $value, },
    };

    my $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 201 );
    ok( $article_url = $res->header('location') );
    ok( ($article_id) = $article_url =~ qr[/article/(\d+)] );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},   $article_id );
    is( $content->{Name}, 'Multi-value CF ' . $i );

    my $output            = ref($value) ? $value : [$value];    # scalar input comes out as array reference
    my $article_cf_values = bag(
        { name => 'Content', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',   id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => $output },
    );

    cmp_deeply( $content->{'CustomFields'}, $article_cf_values, 'Article custom field' );
    $i++;
}

{

    sub modify_multi_ok {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $input    = shift;
        my $messages = shift;
        my $output   = shift;
        my $name     = shift;

        my $payload = { CustomFields => { $multi_cf_id => $input, }, };
        my $res     = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
        is( $res->code, 200 );
        is_deeply( $mech->json_response, $messages );

        $res = $mech->get( $article_url, 'Authorization' => $auth, );
        is( $res->code, 200 );

        my $content = $mech->json_response;
        my $values;
        for my $cf ( @{ $content->{CustomFields} } ) {
            next unless $cf->{id} == $multi_cf_id;

            $values = [ sort @{ $cf->{values} } ];
        }
        cmp_deeply( $values, $output, $name || 'New CF value' );
    }

    # starting point: ['multiple', 'values'],
    modify_multi_ok( [ 'multiple', 'values' ], [], [ 'multiple', 'values' ], 'no change' );
    modify_multi_ok(
        [ 'multiple', 'values', 'new' ],
        ['new added as a value for Multi'],
        [ 'multiple', 'new', 'values' ],
        'added "new"'
    );
    modify_multi_ok(
        [ 'multiple', 'new' ],
        ['values is no longer a value for custom field Multi'],
        [ 'multiple', 'new' ],
        'removed "values"'
    );
    modify_multi_ok(
        'replace all',
        [   'replace all added as a value for Multi',
            'multiple is no longer a value for custom field Multi',
            'new is no longer a value for custom field Multi'
        ],
        ['replace all'],
        'replaced all values'
    );
    modify_multi_ok( [], ['replace all is no longer a value for custom field Multi'], [], 'removed all values' );

    modify_multi_ok(
        [ 'foo',                            'foo', 'bar' ],
        [ 'foo added as a value for Multi', undef, 'bar added as a value for Multi' ],
        [ 'bar',                            'foo' ],
        'multiple values with the same name'
    );
    modify_multi_ok( [ 'foo', 'bar' ], [], [ 'bar', 'foo' ], 'multiple values with the same name' );
    modify_multi_ok( ['bar'], ['foo is no longer a value for custom field Multi'],
        ['bar'], 'multiple values with the same name' );
    modify_multi_ok( [ 'bar', 'bar', 'bar' ], [ undef, undef ], ['bar'], 'multiple values with the same name' );
}

done_testing;
