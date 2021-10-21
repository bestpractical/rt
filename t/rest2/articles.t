use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

# Empty DB
{
    my $res = $mech->post_json(
        "$rest_base_path/articles",
        [ { field => 'id', operator => '>', value => 0 } ],
        'Authorization' => $auth,
    );
    is( $res->code,                    200 );
    is( $mech->json_response->{count}, 0 );
}

# Missing Class
{
    my $res = $mech->post_json(
        "$rest_base_path/article",
        { Name => 'Article creation using REST', },
        'Authorization' => $auth,
    );
    is( $res->code,                      400 );
    is( $mech->json_response->{message}, 'Invalid Class' );
}

# Article Creation
my ( $article_url, $article_id );
{
    my $payload = {
        Name    => 'Article creation using REST',
        Summary => 'Article summary',
        Class   => 'General',
    };

    # Rights Test - No CreateArticle
    my $res = $mech->post_json( "$rest_base_path/article", $payload, 'Authorization' => $auth, );
    is( $res->code, 403 );

    # Rights Test - With CreateArticle
    $user->PrincipalObj->GrantRight( Right => 'CreateArticle' );
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

# Rights Test - With ShowArticle
{
    $user->PrincipalObj->GrantRight( Right => 'ShowArticle' );

    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{id},   $article_id );
    is( $content->{Name}, 'Article creation using REST' );

    ok( exists $content->{$_} ) for qw(Creator Created LastUpdated LastUpdatedBy Name Summary);

    my $links = $content->{_hyperlinks};
    is( scalar @$links, 2 );

    is( $links->[0]{ref},  'self' );
    is( $links->[0]{id},   1 );
    is( $links->[0]{type}, 'article' );
    like( $links->[0]{_url}, qr[$rest_base_path/article/$article_id$] );

    is( $links->[1]{ref}, 'history' );
    like( $links->[1]{_url}, qr[$rest_base_path/article/$article_id/history$] );

    my $class = $content->{Class};
    is( $class->{id},   1 );
    is( $class->{type}, 'class' );
    like( $class->{_url}, qr{$rest_base_path/class/1$} );

    my $creator = $content->{Creator};
    is( $creator->{id},   'test' );
    is( $creator->{type}, 'user' );
    like( $creator->{_url}, qr{$rest_base_path/user/test$} );

    my $updated_by = $content->{LastUpdatedBy};
    is( $updated_by->{id},   'test' );
    is( $updated_by->{type}, 'user' );
    like( $updated_by->{_url}, qr{$rest_base_path/user/test$} );
}

# Article Search
{
    my $res = $mech->post_json(
        "$rest_base_path/articles",
        [ { field => 'id', operator => '>', value => 0 } ],
        'Authorization' => $auth,
    );
    is( $res->code, 200 );
    my $content = $mech->json_response;
    is( $content->{count},             1 );
    is( $content->{page},              1 );
    is( $content->{per_page},          20 );
    is( $content->{total},             1 );
    is( scalar @{ $content->{items} }, 1 );

    my $article = $content->{items}->[0];
    is( $article->{type}, 'article' );
    is( $article->{id},   1 );
    like( $article->{_url}, qr{$rest_base_path/article/1$} );
}

# Article Update
{
    my $payload = { Name => 'Article update using REST', };

    # Rights Test - No ModifyArticle
    my $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is( $res->code, 403 );
    }
    is_deeply( $mech->json_response, ['Article Article creation using REST: Permission Denied'] );

    $user->PrincipalObj->GrantRight( Right => 'ModifyArticle' );

    $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply(
        $mech->json_response,
        [   'Article Article update using REST: Name changed from "Article creation using REST" to "Article update using REST"'
        ]
    );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{Name}, 'Article update using REST' );

    # update again with no changes
    $res = $mech->put_json( $article_url, $payload, 'Authorization' => $auth, );
    is( $res->code, 200 );
    is_deeply( $mech->json_response, [] );

    $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    $content = $mech->json_response;
    is( $content->{Name}, 'Article update using REST' );
}

# Transactions
{
    my $res = $mech->get( $article_url, 'Authorization' => $auth, );
    is( $res->code, 200 );

    $res = $mech->get( $mech->url_for_hypermedia('history'), 'Authorization' => $auth, );
    is( $res->code, 200 );

    my $content = $mech->json_response;
    is( $content->{count},             2 );
    is( $content->{page},              1 );
    is( $content->{per_page},          20 );
    is( $content->{total},             2 );
    is( scalar @{ $content->{items} }, 2 );

    for my $txn ( @{ $content->{items} } ) {
        is( $txn->{type}, 'transaction' );
        like( $txn->{_url}, qr{$rest_base_path/transaction/\d+$} );
    }
}

done_testing;
