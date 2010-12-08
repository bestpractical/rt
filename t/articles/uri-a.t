#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 7;

use_ok("RT::URI::a");
my $uri = RT::URI::a->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $class = RT::Class->new( $RT::SystemUser );
$class->Create( Name => 'URItest - '. $$ );
ok $class->id, 'created a class';
my $article = RT::Article->new( $RT::SystemUser );
my ($id, $msg) = $article->Create(
    Name    => 'Testing URI parsing - '. $$,
    Summary => 'In which this should load',
    Class => $class->Id
);
ok($id,$msg);

my $uristr = "a:" . $article->Id;
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::Article", "Object loaded is an article");
is($uri->Object->Id, $article->Id, "Object loaded has correct ID");
is($article->URI, 'fsck.com-article://example.com/article/'.$article->Id, 
   "URI object has correct URI string");
