use strict;
use warnings;

use RT::Test tests => 36;
my ($baseurl, $agent) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for ( 1 .. 5 ) {
    $ticket->Create(
        Subject   => 'Ticket ' . $_,
        Queue     => 'General',
        Owner     => 'root',
        Requestor => 'rss@localhost',
    );
}

ok $agent->login('root', 'password'), 'logged in as root';

$agent->get_ok('/Search/Build.html');
$agent->form_name('BuildQuery');
$agent->field('idOp', '>');
$agent->field('ValueOfid', '0');
$agent->submit('DoSearch');
$agent->follow_link_ok({id => 'page-results'});

for ( 1 .. 5 ) {
    $agent->content_contains('Ticket ' . $_);
}

$agent->follow_link_ok( { text => 'RSS' } );
my $noauth_uri = $agent->uri;
is( $agent->content_type, 'application/rss+xml', 'content type' );
for ( 1 .. 5 ) {
    $agent->content_contains('Ticket ' . $_);
}
my $rss_content = $agent->content;

use XML::Simple;
my $rss = XML::Simple::XMLin( $rss_content );
is( scalar @{ $rss->{item} }, 5, 'item number' );
for ( 1 .. 5 ) {
    is( $rss->{item}[$_-1]{title}, 'Ticket ' . $_, 'title' . $_ );
}

# not login at all
my $agent_b = RT::Test::Web->new;
$agent_b->get_ok($noauth_uri);
is( $agent_b->content_type, 'application/rss+xml', 'content type' );
is( $agent_b->content, $rss_content, 'content' );
$agent_b->get_ok('/', 'back to homepage');
$agent_b->content_lacks( 'Logout', 'still not login' );

# lets login as another user
my $user_b = RT::Test->load_or_create_user(
    Name => 'user_b', Password => 'password',
);
ok $user_b && $user_b->id, 'loaded or created user';
$agent_b->login('user_b', 'password');
$agent_b->get_ok($noauth_uri);
is( $agent_b->content_type, 'application/rss+xml', 'content type' );
is( $agent_b->content, $rss_content, 'content' );
$agent_b->get_ok('/', 'back to homepage');
$agent_b->content_contains( 'Logout', 'still loggedin' );
$agent_b->content_contains( 'user_b', 'still loggedin as user_b' );

