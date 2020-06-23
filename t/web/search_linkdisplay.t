use strict;
use warnings;

use RT::Test tests => undef;
my ( $baseurl, $m ) = RT::Test->started_ok;

my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'ticket foo',
);

my $generic_url = 'http://generic_url.example.com';
my $link = RT::Link->new( RT->SystemUser );
my ($id,$msg) = $link->Create( Base => $ticket->URI, Target => $generic_url, Type => 'RefersTo' );
ok($id, $msg);


my $ticket2 = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'ticket bar',
);

$link = RT::Link->new( RT->SystemUser );
($id,$msg) = $link->Create( Base => $ticket->URI, Target => $ticket2->URI, Type => 'RefersTo' );
ok($id, $msg);



my $class = RT::Class->new( RT->SystemUser );
($id, $msg) = $class->Create( Name => 'Test Class' );
ok ($id, $msg);

my $article = RT::Article->new( RT->SystemUser );
($id, $msg) = $article->Create( Class => $class->Name, Summary => 'Test Article' );
ok ($id, $msg);
$article->Load($id);


$link = RT::Link->new( RT->SystemUser );
($id,$msg) = $link->Create( Base => $ticket->URI, Target => $article->URI, Type => 'RefersTo' );
ok($id, $msg);


ok( $m->login, 'logged in' );

$m->get_ok("/Search/Results.html?Format=id,RefersTo;Query=id=".$ticket->Id);

$m->title_is( 'Found 1 ticket', 'title' );

my $ref = $m->find_link( url_regex => qr!generic_url! );
ok( $ref, "found generic link" );
is( $ref->text, $generic_url, $generic_url . " is displayed" );

$ref = $m->find_link( url_regex => qr!/Ticket/Display.html! );
ok( $ref, "found ticket link" );
is( $ref->text, "#".$ticket2->Id.": ticket bar", $ticket2->Id . " is displayed" );

$ref = $m->find_link( url_regex => qr!/Article/Display.html! );
ok( $ref, "found article link" );
is( $ref->text, $article->URIObj->Resolver->AsString, $article->URIObj->Resolver->AsString . " is displayed" );


# Get a search that returns multiple tickets
$m->get_ok("/Search/Results.html?Format=id,RefersTo;Query=id>0");

ok $m->goto_ticket( $ticket->Id ), 'opened diplay page of ticket # '.$ticket->Id;
my $t_link = $m->find_link( id => "search-tickets-next" )->url;
is ($t_link, "/Ticket/Display.html?id=".$ticket2->Id, 'link to the next ticket in current search found');

diag "Set ShowSearchNavigation to false and confirm we do not load navigation links.";
{
  RT::Test->stop_server;
  RT->Config->Set( 'ShowSearchNavigation' => 0 );
  ($baseurl, $m) = RT::Test->started_ok;

  # Get a search that returns multiple tickets
  $m->get_ok("/Search/Results.html?Format=id,RefersTo;Query=id>0");

  ok $m->goto_ticket( $ticket->Id ), 'opened diplay page of ticket # '.$ticket->Id;
  $t_link = $m->find_link( id => "search-tickets-next" );
  is($t_link, undef, "Search navigation results are not rendered");
}
done_testing;
