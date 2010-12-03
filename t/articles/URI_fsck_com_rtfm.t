#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 12;

use_ok "RT::URI::fsck_com_rtfm";
my $uri = RT::URI::fsck_com_rtfm->new( $RT::SystemUser );

ok $uri;
isa_ok $uri, 'RT::URI::fsck_com_rtfm';
isa_ok $uri, 'RT::URI::base';
isa_ok $uri, 'RT::Base';

is $uri->LocalURIPrefix, 'fsck.com-rtfm://example.com/article/';

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

$uri = RT::URI::fsck_com_rtfm->new( $article->CurrentUser );
is $uri->LocalURIPrefix . $article->id, $uri->URIForObject( $article );

