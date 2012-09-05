
use strict;
use warnings;

use RT::Test tests => 15;

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

{
    my $aid = $article->id;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $msg) = $ticket->Create(
        Queue       => 1,
        Subject     => 'test ticket',
    );
    ok $id, "Created a test ticket";

    # Try searching
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->FromSQL(" RefersTo = 'a:$aid' ");
    is $tickets->Count, 0, "No results yet";

    # try with the full uri
    $tickets->FromSQL(" RefersTo = '@{[ $article->URI ]}' ");
    is $tickets->Count, 0, "Still no results";

    # add the link
    $ticket->AddLink( Type => 'RefersTo', Target => "a:$aid" );

    # verify the ticket has it
    my @links = @{$ticket->RefersTo->ItemsArrayRef};
    is scalar @links, 1, "Has one RefersTo link";
    is ref $links[0]->TargetObj, "RT::Article", "Link points to an article";
    is $links[0]->TargetObj->id, $aid, "Link points to the article we specified";

    # search again
    $tickets->FromSQL(" RefersTo = 'a:$aid' ");
    is $tickets->Count, 1, "Found one ticket with short URI";

    # search with the full uri
    $tickets->FromSQL(" RefersTo = '@{[ $article->URI ]}' ");
    is $tickets->Count, 1, "Found one ticket with full URI";
}
