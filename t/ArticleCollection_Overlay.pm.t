#!/usr/bin/perl -w

use Test::More qw/no_plan/;
use_ok(RT);
RT::LoadConfig();
RT::Init();
use_ok( RT::FM::ArticleCollection);
my $arts =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts->LimitName (VALUE => 'testing');
is($arts->Count, 0, 'Found no artlcles with summaries matching the word "testing"');

my $arts2 =RT::FM::ArticleCollection->new($RT::SystemUser);
#$arts2->LimitName (VALUE => 'test');
#is($arts2->Count, 3, 'Found 3 artlcles with summaries matching the word "test"');


 $arts =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts->LimitSummary (VALUE => 'testing');
is($arts->Count, 0, 'Found no artlcles with summaries matching the word "testing"');

 $arts2 =RT::FM::ArticleCollection->new($RT::SystemUser);
$arts2->LimitSummary (VALUE => 'test');
is($arts2->Count, 3, 'Found 3 artlcles with summaries matching the word "test"');


my $new_art = RT::FM::Article->new($RT::SystemUser);
$new_art->Create (Class => 1,
                  Name => 'CFSearchTest1',
                  CustomField-1 => 'testing' );


ok( $new_art->Id, " Created a testable article");

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

