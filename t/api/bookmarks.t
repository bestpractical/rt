use strict;
use warnings;
use RT::Test tests => 32;

my ( $url, $m ) = RT::Test->started_ok;
my $root = RT::Test->load_or_create_user( Name => 'root' );

my @tickets = RT::Test->create_tickets( { },  map { { Subject => "Test $_" } } ( 1 .. 9 ) );

# 4.2 gives us $user->ToggleBookmark which is nicer
$root->SetAttribute( Name => 'Bookmarks', Content => { map { $_ => 1 } (3,6,9) } );

my $cu = RT::CurrentUser->new($root);
my $bookmarks = RT::Tickets->new($cu);
for my $search ( "Queue = 'General' AND id = '__Bookmarked__'",
                 "id = '__Bookmarked__' AND Queue = 'General'" ) {
    $bookmarks->FromSQL($search);
    #diag $bookmarks->BuildSelectQuery;
    is($bookmarks->Count,3,"Found my 3 bookmarks for [$search]");
}
