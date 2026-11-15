
use strict;
use warnings;

use RT::Test tests => undef;

use_ok 'RT::Articles';
use_ok 'RT::Classes';
use_ok 'RT::Class';

my $CLASS = 'ArticleTest-'.$$;

my $user = RT::CurrentUser->new('root');

my $class = RT::Class->new($user);


my ($id, $msg) = $class->Create(Name =>$CLASS);
ok ($id, $msg);



my $article = RT::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::Article'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record') , "It's a searchbuilder record!");


($id, $msg) = $article->Create( Class => $CLASS, Summary => $CLASS, Name => undef);
ok (!$id, $msg);

($id, $msg) = $article->Create( Class => $CLASS, Summary => $CLASS, Name => '');
ok (!$id, $msg);

($id, $msg) = $article->Create( Class => $CLASS, Summary => $CLASS, Name => 'test 1');
ok ($id, $msg);
$article->Load($id);
is ($article->Summary, $CLASS, "The summary is set correct");
my $at = RT::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);




my  $a1 = RT::Article->new($RT::SystemUser);
 ($id, $msg)  = $a1->Create(Class => $class->id, Name => 'ValidateNameTest'.$$);
ok ($id, $msg);



my  $a2 = RT::Article->new($RT::SystemUser);
($id, $msg)  = $a2->Create(Class => $class->id, Name => 'ValidateNameTest'.$$);
ok (!$id, $msg);

my  $a3 = RT::Article->new($RT::SystemUser);
($id, $msg)  = $a3->Create(Class => $class->id, Name => 'ValidateNameTest2'.$$);
ok ($id, $msg);
($id, $msg) =$a3->SetName('ValidateNameTest'.$$);

ok (!$id, $msg);

($id, $msg) =$a3->SetName('ValidateNametest2'.$$);

ok ($id, $msg);





my $newart = RT::Article->new($RT::SystemUser);
$newart->Create(Name => 'DeleteTest'.$$, Class => '1');
$id = $newart->Id;

ok($id, "New article has an id");


 $article = RT::Article->new($RT::SystemUser);
$article->Load($id);
ok ($article->Id, "Found the article");
my $val;
 ($val, $msg) = $article->Delete();
ok ($val, "Article Deleted: $msg");

 $a2 = RT::Article->new($RT::SystemUser);
$a2->Load($id);
ok ($a2->Disabled, "the article is disabled");



my $class1 = RT::Class->new($RT::SystemUser);
($id, $msg) = $class1->Create(Name => "ScopedClassTest1-$$");
ok ($id, $msg);

my $class2 = RT::Class->new($RT::SystemUser);
($id, $msg) = $class2->Create(Name => "ScopedClassTest2-$$");
ok ($id, $msg);

my $a4 = RT::Article->new($RT::SystemUser);
($id, $msg) = $a4->Create(Class => $class1->id, Name => "ScopedClassTest$$" );
ok ($id, $msg);

my $a5 = RT::Article->new($RT::SystemUser);
($id, $msg) = $a5->Create(Class => $class1->id, Name => "ScopedClassTest$$" );
ok (!$id, $msg);

my $a6 = RT::Article->new($RT::SystemUser);
($id, $msg) = $a6->Create(Class => $class2->id, Name => "ScopedClassTest$$" );
ok ($id, $msg);
is ($a6->ClassObj->Name, $class2->Name, 'Class name is ' . $class2->Name);

# Can't change class if Name is used in destination class
($val, $msg) = $a6->SetClass($class1->id);
ok (!$val, $msg);

($val, $msg) = $a6->SetName('Changed name');
ok ($val, $msg);
($val, $msg) = $a6->SetClass($class1->id);
ok ($val, $msg);

my $a7 = RT::Article->new($RT::SystemUser);
($id, $msg) = $a7->Create(Class => $class1->id, Name => "ScopedClassTest$$-2" );
ok ($id, $msg);
($val, $msg) = $a7->SetName("Changed name");
ok (!$val, $msg);
is ($msg, $a7->loc('Name in use'), 'Name in use message');


# NOT OK
#$RT::Handle->SimpleQuery("DELETE FROM Links");

my $article_a = RT::Article->new($RT::SystemUser);
($id, $msg) = $article_a->Create( Class => $CLASS, Summary => "ArticleTestlink1".$$, Name => 'test 2');
ok($id,$msg);

my $article_b = RT::Article->new($RT::SystemUser);
($id, $msg) = $article_b->Create( Class => $CLASS, Summary => "ArticleTestlink2".$$, Name => 'test 3');
ok($id,$msg);

# Create a link between two articles
($id, $msg) = $article_a->AddLink( Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);

# Make sure that Article Bs "ReferredToBy" links object refers to to this article
my $refers_to_b = $article_b->ReferredToBy;
is($refers_to_b->Count, 1, "Found one thing referring to b");
my $first = $refers_to_b->First;
ok ($first->isa('RT::Link'), "IT's an RT link - ref ".ref($first) );
is($first->TargetObj->Id, $article_b->Id, "Its target is B");

ok($refers_to_b->First->BaseObj->isa('RT::Article'), "Yep. its an article");


# Make sure that Article A's "RefersTo" links object refers to this article"
my $referred_To_by_a = $article_a->RefersTo;
is($referred_To_by_a->Count, 1, "Found one thing referring to b ".$referred_To_by_a->Count. "-".$referred_To_by_a->First->id . " - ".$referred_To_by_a->Last->id);
 $first = $referred_To_by_a->First;
ok ($first->isa('RT::Link'), "IT's an RT link - ref ".ref($first) );
is ($first->TargetObj->Id, $article_b->Id, "Its target is B - " . $first->TargetObj->Id);
is ($first->BaseObj->Id, $article_a->Id, "Its base is A");

ok($referred_To_by_a->First->BaseObj->isa('RT::Article'), "Yep. its an article");

# Delete the link
($id, $msg) = $article_a->DeleteLink(Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);


# Create an Article A RefersTo Ticket 1 from the Articles side
use RT::Ticket;


my $tick = RT::Ticket->new($RT::SystemUser);
$tick->Create(Subject => "Article link test ", Queue => 'General');
$tick->Load($tick->Id);
ok ($tick->Id, "Found ticket ".$tick->id);
($id, $msg) = $article_a->AddLink(Type => 'RefersTo', Target => $tick->URI);
ok($id,$msg);

# Find all tickets whhich refer to Article A

use RT::Tickets;
use RT::Links;

my $tix = RT::Tickets->new($RT::SystemUser);
ok ($tix, "Got an RT::Tickets object");
ok ($tix->LimitReferredToBy($article_a->URI)); 
is ($tix->Count, 1, "Found one ticket linked to that article");
is ($tix->First->Id, $tick->id, "It's even the right one");



# Find all articles which refer to Ticket 1
use RT::Articles;

my $articles = RT::Articles->new($RT::SystemUser);
ok($articles->isa('RT::Articles'), "Created an article collection");
ok($articles->isa('RT::SearchBuilder'), "Created an article collection");
ok($articles->isa('DBIx::SearchBuilder'), "Created an article collection");
ok($tick->URI, "The ticket does still have a URI");
$articles->LimitRefersTo($tick->URI);

is($articles->Count(), 1);
is ($articles->First->Id, $article_a->Id);
is ($articles->First->URI, $article_a->URI);



# Find all things which refer to ticket 1 using the RT API.

my $tix2 = RT::Links->new($RT::SystemUser);
ok ($tix2->isa('RT::Links'));
ok($tix2->LimitRefersTo($tick->URI));
is ($tix2->Count, 1);
is ($tix2->First->BaseObj->URI ,$article_a->URI);



# Delete the link from the RT side.
my $t2 = RT::Ticket->new($RT::SystemUser);
$t2->Load($tick->Id);
($id, $msg)= $t2->DeleteLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg . " - $id - $msg");

# it is actually deleted
my $tix3 = RT::Links->new($RT::SystemUser);
$tix3->LimitReferredToBy($tick->URI);
is ($tix3->Count, 0);

# Recreate the link from teh RT site
($id, $msg) = $t2->AddLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg);

# Find all tickets whhich refer to Article A

# Find all articles which refer to Ticket 1




my $art = RT::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => $CLASS, Name => 'test 4');
ok ($id,$msg);

ok($art->URI);
ok($art->__Value('URI') eq $art->URI, "The uri in the db is set correctly");




 $art = RT::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => $CLASS, Name => 'test 5');
ok ($id,$msg);

ok($art->URIObj);
ok($art->__Value('URI') eq $art->URIObj->URI, "The uri in the db is set correctly");


my $art_id = $art->id;
$art = RT::Article->new($RT::SystemUser);
$art->Load($art_id);
is ($art->Id, $art_id, "Loaded article 1");
my $s =$art->Summary;
($val, $msg) = $art->SetSummary("testFoo");
ok ($val, $msg);
ok ($art->Summary eq 'testFoo', "The Summary was set to foo");
my $t = $art->Transactions();
my $trans = $t->Last;
ok ($trans->Type eq 'Set', "It's a Set transaction");
ok ($trans->Field eq 'Summary', "it is about setting the Summary");
is  ($trans->NewValue , 'testFoo', "The new content is 'foo'");
is ($trans->OldValue,$s, "the old value was preserved");

sub create_topic {
    my %args  = @_;
    my $topic = RT::Topic->new( RT->SystemUser );
    my ( $id, $msg ) = $topic->Create(
        ObjectType => 'RT::Class',
        ObjectId   => $class->Id,
        Parent     => 0,
        %args,
    );
    ok( $id, "Created topic $args{Name}: $msg" );
    return $topic;
}

sub object_topic_count {
    my $topic_id = shift;
    my $object_topics = RT::ObjectTopics->new( RT->SystemUser );
    $object_topics->LimitToTopic($topic_id);
    return $object_topics->Count;
}

sub create_article_with_topic {
    my ( $name, $topic ) = @_;
    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => $class->Id, Name => $name );
    ok( $id, "Created article $name: $msg" );
    ( $id, $msg ) = $article->AddTopic( Topic => $topic->Id );
    ok( $id, "Added topic " . $topic->Name . " to article $name: $msg" );
    return $article;
}

diag "DeleteAll on a topic linked to an article";
{
    my $topic   = create_topic( Name => 'DeleteAllLinked' );
    my $article = create_article_with_topic( 'DeleteAllLinkedArticle', $topic );
    my $topic_id = $topic->Id;

    my ( $ok, $msg ) = $topic->DeleteAll;
    is( $ok,  1,                    'DeleteAll returns success' );
    is( $msg, 'Topic tree deleted', 'DeleteAll returns the success message' );

    my $deleted = RT::Topic->new( RT->SystemUser );
    $deleted->Load($topic_id);
    ok( !$deleted->Id, 'Topic is gone' );
    is( object_topic_count($topic_id), 0, 'No ObjectTopics rows reference the deleted topic' );
    is( $article->Topics->Count,       0, 'Article has no topics' );
}

diag "DeleteAll on a parent whose child topic is linked to an article";
{
    my $parent = create_topic( Name => 'DeleteAllParent' );
    my $child  = create_topic( Name => 'DeleteAllChild', Parent => $parent->Id );
    my $parent_article = create_article_with_topic( 'DeleteAllParentArticle', $parent );
    my $child_article  = create_article_with_topic( 'DeleteAllChildArticle',  $child );
    my ( $parent_id, $child_id ) = ( $parent->Id, $child->Id );

    my ( $ok, $msg ) = $parent->DeleteAll;
    is( $ok,  1,                    'DeleteAll returns success' );
    is( $msg, 'Topic tree deleted', 'DeleteAll returns the success message' );

    for my $id ( $parent_id, $child_id ) {
        my $deleted = RT::Topic->new( RT->SystemUser );
        $deleted->Load($id);
        ok( !$deleted->Id, "Topic $id is gone" );
        is( object_topic_count($id), 0, "No ObjectTopics rows reference topic $id" );
    }
    is( $parent_article->Topics->Count, 0, 'Parent article has no topics' );
    is( $child_article->Topics->Count,  0, 'Child article has no topics' );
}

diag "Delete re-parents children and removes the topic's ObjectTopics rows";
{
    my $grandparent = create_topic( Name => 'DeleteGrandparent' );
    my $parent      = create_topic( Name => 'DeleteParent', Parent => $grandparent->Id );
    my $child       = create_topic( Name => 'DeleteChild',  Parent => $parent->Id );
    my $parent_article = create_article_with_topic( 'DeleteParentArticle', $parent );
    my $child_article  = create_article_with_topic( 'DeleteChildArticle',  $child );
    my $parent_id = $parent->Id;

    my ( $ok, $msg ) = $parent->Delete;
    is( $ok,  1,               'Delete returns success' );
    is( $msg, 'Topic deleted', 'Delete returns the success message' );

    my $deleted = RT::Topic->new( RT->SystemUser );
    $deleted->Load($parent_id);
    ok( !$deleted->Id, 'Topic is gone' );
    is( object_topic_count($parent_id), 0, 'No ObjectTopics rows reference the deleted topic' );
    is( $parent_article->Topics->Count, 0, 'Article of the deleted topic has no topics' );

    $child->Load( $child->Id );
    ok( $child->Id, 'Child topic still exists' );
    is( $child->Parent, $grandparent->Id, 'Child topic moved up to the grandparent' );
    is( $child_article->Topics->Count, 1, 'Child article keeps its topic' );
    is( $child_article->Topics->First->Topic, $child->Id, 'Child article topic is the child topic' );
}

diag "Delete on a top-level topic moves its children to the top level";
{
    my $parent = create_topic( Name => 'DeleteTopLevelParent' );
    my $child  = create_topic( Name => 'DeleteTopLevelChild', Parent => $parent->Id );

    my ( $ok, $msg ) = $parent->Delete;
    is( $ok,  1,               'Delete returns success' );
    is( $msg, 'Topic deleted', 'Delete returns the success message' );

    $child->Load( $child->Id );
    ok( $child->Id, 'Child topic still exists' );
    is( $child->Parent, 0, 'Child topic is now a top-level topic' );
}

diag "Delete and DeleteAll require AdminTopics";
{
    my $topic   = create_topic( Name => 'DeleteNoRight' );
    my $article = create_article_with_topic( 'DeleteNoRightArticle', $topic );

    my $user = RT::Test->load_or_create_user( Name => 'topic-no-admin' );
    my $topic_as_user = RT::Topic->new( RT::CurrentUser->new($user) );
    $topic_as_user->Load( $topic->Id );
    is( $topic_as_user->Id, $topic->Id, 'Loaded topic as unprivileged user' );

    for my $method (qw(Delete DeleteAll)) {
        my ( $ok, $msg ) = $topic_as_user->$method;
        is( $ok,  0,                   "$method returns failure without AdminTopics" );
        is( $msg, 'Permission Denied', "$method returns the permission message" );
    }

    my $still_there = RT::Topic->new( RT->SystemUser );
    $still_there->Load( $topic->Id );
    is( $still_there->Id, $topic->Id, 'Topic still exists' );
    is( object_topic_count( $topic->Id ), 1, 'ObjectTopics row still exists' );
}

done_testing();
