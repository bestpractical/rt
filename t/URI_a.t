#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
eval 'use RT::Test; 1'
    or plan skip_all => 'requires 3.8 to run tests.';
plan tests => 9;

{
my ($ret, $msg) = $RT::Handle->InsertSchema(undef,'etc/');
ok($ret,"Created Schema: ".($msg||''));
($ret, $msg) = $RT::Handle->InsertACL(undef,'etc/');
ok($ret,"Created ACL: ".($msg||''));
}

RT->Config->Set('Plugins',qw(RT::FM));

use_ok("RT::URI::a");
my $uri = RT::URI::a->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $class = RT::FM::Class->new( $RT::SystemUser );
$class->Create( Name => 'URItest - '. $$ );
ok $class->id, 'created a class';
my $article = RT::FM::Article->new( $RT::SystemUser );
my ($id, $msg) = $article->Create(
    Name    => 'Testing URI parsing - '. $$,
    Summary => 'In which this should load',
    Class => $class->Id
);
ok($id,$msg);

my $uristr = "a:" . $article->Id;
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::FM::Article", "Object loaded is an article");
is($uri->Object->Id, $article->Id, "Object loaded has correct ID");
is($article->URI, 'fsck.com-rtfm://example.com/article/'.$article->Id, 
   "URI object has correct URI string");
