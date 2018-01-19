use strict;
use warnings;

use RT::Test tests => undef;
use Data::Printer;

my $m = RT::Test->started_ok;
my $url = $m->rt_base_url;
diag('Started server at ' . $url);

my $article = RT::Article->new($RT::SystemUser);
my ( $id, $msg ) = $article->Create(
    Class   => 'General',
    Name    => 'My Article',
    'CustomField-Content' => 'My Article Test Content',
);
ok( $id, $msg );
(my $ret, $msg) = $article->Load(1);
ok ($ret, $msg);

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Load('General');
ok( $queue, 'Loaded General Queue' );
($ret, $msg) = $queue->SetArticleIncluded($article->id);
ok( $ret, $msg );

ok $m->login(root => 'password'), "logged in";
$m->goto_create_ticket('General');
$m->scraped_id_is('Content', 'My Article Test Content');

done_testing;
