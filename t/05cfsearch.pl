#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;;

use lib ("/opt/rt3/lib","/opt/rt3/local/lib");
use RT;

# Load the config file
RT::LoadConfig();

#Connect to the database and get RT::SystemUser and RT::Nobody loaded
RT::Init();

my $suffix = "-".$$;


#Get the current user all loaded
my $CurrentUser = $RT::SystemUser;

use RT::FM::Class;
use RT::FM::Article;
use RT::CustomField;

my $class = new RT::FM::Class($CurrentUser);
my $cf = new RT::CustomField($CurrentUser);
my $article1 = new RT::FM::Article($CurrentUser);
my $article2 = new RT::FM::Article($CurrentUser);

my $classname = 'TestClass'.$suffix;
my $cfname = 'TestCF'.$suffix;
my $article1name = 'TestArticle1'.$suffix;
my $article2name = 'TestArticle2'.$suffix;

  #create class
my ($val,$msg) =  $class->Create( Name => $classname, Description => 'class for cf tests');

ok ($val,$msg);

# create cf
$cf->Create(Name => $cfname, LookupType => 'RT::FM::Class-RT::FM::Article', Type => 'Select', MaxValues => 1, Description => 'singleselect cf for tests');

# attach cf to class
$cf->AddToObject( $class);
  
# create two cf-values
$cf->AddValue( Name => 'Value1');
$cf->AddValue( Name => 'Value2');

# create articles
$article1->Create( Name => $article1name, Summary => 'Test', Class => $class->Id);
$article2->Create( Name => $article2name, Summary => 'Test', Class => $class->Id);
  
# attach 1st cf-value to article
$article1->AddCustomFieldValue(Field => $cf->Id, Value => 'Value1');
$article2->AddCustomFieldValue(Field => $cf->Id, Value => 'Value2');

# search for articles containing 1st value
my $articles = new RT::FM::ArticleCollection($CurrentUser);
$articles->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);

$articles->LimitCustomField( FIELD => $cf->Id, VALUE => 'Value1' );

is($articles->Count,1, "Found ".$articles->Count);

my $articles2 = new RT::FM::ArticleCollection($CurrentUser);

$articles2->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);

$articles2->LimitCustomField( FIELD => $cf, VALUE => 'Value1' );

is($articles2->Count, 1,  "CF search by Object is ");

my $articles3 = new RT::FM::ArticleCollection($CurrentUser);
$articles3->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);
$articles3->LimitCustomField( FIELD => $cf->Name, VALUE => 'Value1' );
is($articles3->Count, 1,  "CF search by Name is ");

1;
