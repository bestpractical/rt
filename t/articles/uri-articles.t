
use strict;
use warnings;

use RT::Test tests => undef;
use Test::Warn;

use_ok "RT::URI::fsck_com_article";
my $uri = RT::URI::fsck_com_article->new( $RT::SystemUser );

ok $uri;
isa_ok $uri, 'RT::URI::fsck_com_article';
isa_ok $uri, 'RT::URI::base';
isa_ok $uri, 'RT::Base';

is $uri->LocalURIPrefix, 'fsck.com-article://example.com';

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

$uri = RT::URI::fsck_com_article->new( $article->CurrentUser );
is $uri->URIForObject( $article ),
    'fsck.com-article://example.com/article/' . $article->id,
        'Got correct URIForObject';
my $article_id = $article->Id;
ok ($uri->ParseURI("fsck.com-article://example.com/article/$article_id"),
    'Parsed URI');

ok ($article->Delete(), 'Deleted article');

ok($article->Disabled, 'deleted article is actually just disabled');

ok (!$uri->ParseURI("fsck.com-article://foo.com/article/$article_id"),
    'ParseURI returned false with incorrect Organization');

done_testing();
