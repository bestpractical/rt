#!/usr/bin/perl -w

use Test::More qw/no_plan/;
use_ok(RT);
RT::LoadConfig();
RT::Init();

use_ok( RT::FM::ArticleCollection);
use_ok( RT::FM::ClassCollection);

my $class = RT::FM::Class->new($RT::SystemUser);
my ($id,$msg) = $class->Create(Name => 'CollectionTest-'.$$);
ok($id,$msg);

my $art = RT::FM::Article->new($RT::SystemUser);
($id,$msg) = $art->Create( Class => $class->id,
            Name => 'Collection-1-'.$$,
             Summary => 'Coll-1-'.$$);

ok($id,$msg);

my $arts =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts->LimitName (VALUE => 'Collection-1-'.$$.'fake');
is($arts->Count, 0, "Found no artlcles with names matching something that is not there");

my $arts2 =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts2->LimitName (VALUE => 'Collection-1-'.$$);
is($arts2->Count, 1, 'Found one with names matching the word "test"');



my $arts =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts->LimitSummary (VALUE => 'Coll-1-'.$$.'fake');
is($arts->Count, 0, 'Found no artlcles with summarys matching something that is not there');

my $arts2 =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts2->LimitSummary (VALUE => 'Coll-1-'.$$);
is($arts2->Count, 1, 'Found one with summarys matching the word "Coll-1"');



my $new_art = RT::FM::Article->new($RT::SystemUser);
($id,$msg) = $new_art->Create (Class => $class->id,
                  Name => 'CFSearchTest1'.$$,
                  CustomField-1 => 'testing'.$$ );


ok( $id,$msg . " Created a testable article");

 $arts = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($arts->isa('RT::FM::ArticleCollection'), "Got an article collection");
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => 'est');
is ($arts->Count ,1, "Found 1 cf values matching 'est'");

 $arts = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($arts->isa('RT::FM::ArticleCollection'), "Got an article collection");
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => 'est', FIELD => '1');
is ($arts->Count, 1, "Found 1 cf values matching 'est' for CF1 ");


 $arts = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($arts->isa('RT::FM::ArticleCollection'), "Got an article collection");
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => 'est', FIELD => '6');
ok ($arts->Count == '0', "Found no cf values matching 'est' for CF 6  ");

 $arts = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($arts->isa('RT::FM::ArticleCollection'), "Got an article collection");
$arts->LimitCustomField( OPERATOR => 'NOT LIKE', VALUE => 'blah', FIELD => '1');
ok ($arts->Count == 7, "Found 7 articles with custom field values not matching blah-"  . $arts->Count);

 $arts = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($arts->isa('RT::FM::ArticleCollection'), "Got an article collection");
$arts->LimitCustomField( OPERATOR => 'NOT LIKE', VALUE => 'est', FIELD => '1');
ok ($arts->Count == 6, "Found 6 cf values matching 'est' for CF 6  -"  . $arts->Count);


my $ac = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($ac->isa('RT::FM::ArticleCollection'));
ok($ac->isa('RT::FM::SearchBuilder'));
ok ($ac->isa('DBIx::SearchBuilder'));
ok ($ac->LimitRefersTo('http://dead.link'));
ok ($ac->Count == 0);


$ac = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($ac->isa('RT::FM::ArticleCollection'));
ok($ac->isa('RT::FM::SearchBuilder'));
ok ($ac->isa('DBIx::SearchBuilder'));
ok ($ac->LimitReferredToBy('http://dead.link'));
ok ($ac->Count == 0);

