use strict;
use warnings;

use RT::Test tests => undef;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';

my ($root, $root_id);
{
    $root = RT::User->new( RT->SystemUser );
    $root->Load('root');
    ok $root_id = $root->id, 'found root';
}

RT->Config->Set( 'ArticleSearchFields', {
    Name         => 'STARTSWITH',
    Summary      => 'LIKE',
    'CF.1'       => 'LIKE',
});

my $group = RT::Test->load_or_create_group('Engineers');

my ($baseurl, $m) = RT::Test->started_ok;
$m->login;

# test users auto completer
{
    $m->get_ok('/Helpers/Autocomplete/Users?term=eNo');
    require JSON;
    is_deeply(
        JSON::from_json( $m->content ),
        [   {   id      => 14,
                "value" => "root\@localhost",
                "label" => "root (Enoch Root)",
                "text"  => 'eNo',
            }
        ]
    );
}

{
    $m->get_ok('/Helpers/Autocomplete/Users?return=id&term=eNo');
    require JSON;
    is_deeply(
        JSON::from_json( $m->content ),
        [   {   id      => 14,
                "value" => 14,
                "label" => "root (Enoch Root)",
                "text"  => 'eNo',
            }
        ]
    );
}

# test groups auto completer
{
    $m->get_ok('/Helpers/Autocomplete/Groups?term=eng');
    is_deeply(
        JSON::from_json( $m->content ),
        [   {   id    => $group->Id,
                value => 'Engineers',
                label => 'Engineers',
            }
        ]
    );
}

{
    $m->get_ok('/Helpers/Autocomplete/Groups?return=id&term=eng');
    is_deeply(
        JSON::from_json( $m->content ),
        [   {   id    => $group->Id,
                value => $group->Id,
                label => 'Engineers',
            }
        ]
    );
}

# test articles auto completer with return=id
{
    # Create a test article for autocomplete
    my $article_name = 'Autocomplete Test Article ' . $$;
    my $article = RT::Article->new(RT->SystemUser);
    my ($article_id, $msg) = $article->Create(
        Class       => 'General',
        Name        => $article_name,
        Summary     => 'Test article for autocomplete functionality',
    );
    ok($article_id, $msg);

    # Test autocomplete with return=id parameter
    $m->get_ok('/Helpers/Autocomplete/Articles?return=id&queue=1&term=Autocomplete');
    require JSON;
    my $content = JSON::from_json( $m->content );
    is( ref($content), 'ARRAY', 'Articles autocomplete returns array' );
    ok( exists $content->[0]->{value}, 'Article autocomplete result has value field' );
    is( $content->[0]->{value}, $article_id, 'Article autocomplete returns correct article ID' );
}

# test ticket's People page
{
    my $ticket = RT::Test->create_ticket( Queue => $q->id );
    ok $ticket && $ticket->id, "created ticket";

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok( {text => 'People'} );
    $m->form_number(3);
    $m->select( UserField => 'RealName' );
    $m->field( UserString => 'eNo' );
    $m->click('OnlySearchForPeople');

    my $form = $m->form_number(3);
    my $input = $form->find_input('Ticket-AddWatcher-Principal-'. $root->id );
    ok $input, 'input is there';
}

# test users' admin UI
{
    $m->get_ok('/Admin/Users/');

    $m->form_number(4);
    $m->select( UserField => 'RealName' );
    $m->field( UserString => 'eNo' );
    $m->submit;

    like $m->uri, qr{\QAdmin/Users/Modify.html?id=$root_id\E};
}

# create a cf for testing
my $cf;
{
    $cf = RT::CustomField->new(RT->SystemUser);
    my ($id,$msg) = $cf->Create(
        Name => 'Test',
        Type => 'Select',
        MaxValues => '1',
        Queue => $q->id,
    );
    ok($id,$msg);

    ($id,$msg) = $cf->AddValue(Name => 'Enoch', Description => 'Root');
    ok($id,$msg);
}

# test custom field values auto completer
{
    $m->get_ok('/Helpers/Autocomplete/CustomFieldValues?term=eNo&Object-RT::Ticket--CustomField-'. $cf->id .'-Value&ContextId=1&ContextType=RT::Queue');
    require JSON;
    is_deeply(
        JSON::from_json( $m->content ),
        [{"value" =>  "Enoch","label" => "Enoch (Root)"}]
    );
}

# test articles auto completer
{
    my $article_name = 'Case-Sensitive Sample Article ' . $$;
    my $art = RT::Article->new($RT::SystemUser);
    my ($id,$msg) = $art->Create(
        Class           => 'General',
        Name            => $article_name,
        Description     => 'A Case-Sensitive Article Description',
        Summary         => 'A Case-Sensitive Article Summary',
        'CustomField-1' => 'Case-sensitive Article Content',
    );
    ok($id,$msg);

    my $result = [{ "label" => $article_name, "value" => $id }];

    # test Name
    $m->get_ok('/Helpers/Autocomplete/Articles?return=id&queue=1&term=case-sensitive+sample+article');
    is_deeply( JSON::from_json( $m->content ), $result, 'Found by Name' );

    # test Summary
    $m->get_ok('/Helpers/Autocomplete/Articles?return=id&queue=1&term=article+summary');
    is_deeply( JSON::from_json( $m->content ), $result, 'Found by Summary' );

    # test CF.Content
    $m->get_ok('/Helpers/Autocomplete/Articles?return=id&queue=1&term=article+content');
    is_deeply( JSON::from_json( $m->content ), $result, 'Found by Content' );
}

$m->logout;

# Create a user with limited rights
my $user = RT::User->new(RT->SystemUser);
my ($user_id, $user_msg) = $user->Create(
    Name => 'limited_user_' . $$,
    Password => 'password',
    Privileged => 1,
);
ok($user_id, "Created limited user: $user_msg");
$m->login($user->Name, 'password');

# test articles autocomplete with rights-based filtering and max limit
{
    # Create a second article class
    my $class1 = RT::Class->new(RT->SystemUser);
    my ($class1_id, $class1_msg) = $class1->Create(
        Name => 'Visible-' . $$,
        Description => 'Visible class',
    );
    ok($class1_id, "Created visible class: $class1_msg");

    my $class2 = RT::Class->new(RT->SystemUser);
    my ($class2_id, $class2_msg) = $class2->Create(
        Name => 'Hidden-' . $$,
        Description => 'Hidden class',
    );
    ok($class2_id, "Created hidden class: $class2_msg");

    # Grant ShowArticle right only on the visible class
    my ($ok, $msg) = $user->PrincipalObj->GrantRight(
        Right => 'ShowArticle',
        Object => $class1,
    );
    ok($ok, "Granted ShowArticle on visible class: $msg");

    # Create 3 articles with the same search term
    # Article 1 is visible, article 2 is hidden, article 3 is visible
    my @articles;
    my @classes = ($class1, $class2, $class1);
    for my $i (1..3) {
        my $art = RT::Article->new(RT->SystemUser);
        my ($id, $art_msg) = $art->Create(
            Class   => $classes[$i-1]->Name,
            Name    => "MaxResults Article $i " . $$,
            Summary => "MaxResults test article $i",
        );
        ok($id, "Created article $i: $art_msg");
        push @articles, $art;
    }

    # Test with max=2: should get 2 results from the 2 visible articles
    $m->get_ok('/Helpers/Autocomplete/Articles?return=id&term=MaxResults&max=2');
    my $results = JSON::from_json($m->content);

    is(scalar @$results, 2, 'Returns 2 results when max=2 and 2 visible articles exist');
    is($results->[0]->{value}, $articles[0]->id, 'First visible article is returned');
    is($results->[1]->{value}, $articles[2]->id, 'Third article (second visible) is returned');
}

done_testing();
