use strict;
use warnings;
use RT;

# Load the config file
use RT::Test tests => 63;

#Connect to the database and get RT::SystemUser and RT::Nobody loaded


#Get the current user all loaded
my $CurrentUser = RT->SystemUser;

my $queue = RT::Queue->new($CurrentUser);
$queue->Load('General') || Abort(loc("Queue could not be loaded."));

my $child_ticket = RT::Ticket->new( $CurrentUser );
my ($childid) = $child_ticket->Create(
    Subject => 'test child',
    Queue => $queue->Id,
);
ok($childid, "We created a child ticket");

my $parent_ticket = RT::Ticket->new( $CurrentUser );
my ($parentid) = $parent_ticket->Create(
    Subject => 'test parent',
    Children => [ $childid ],
    Queue => $queue->Id,
);
ok($parentid, "We created a parent ticket");


my $Collection = RT::Tickets->new($CurrentUser);
$Collection->LimitMemberOf( $parentid );
is($Collection->Count,1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $childid, "We found the collection of all children of $parentid with Limit");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("MemberOf = $parentid");
is($Collection->Count, 1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $childid, "We found the collection of all children of $parentid with TicketSQL");


$Collection = RT::Tickets->new($CurrentUser);
$Collection->LimitHasMember ($childid);
is($Collection->Count,1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $parentid, "We found the collection of all parents of $childid with Limit");


$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("HasMember = $childid");
is($Collection->Count,1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $parentid, "We found the collection of all parents of $childid with TicketSQL");


# Now we find a collection of all the tickets which have no members. they should have no children.
$Collection = RT::Tickets->new($CurrentUser);
$Collection->LimitHasMember('');
# must contain child; must not contain parent
my %has;
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$childid}, "The collection has our child - $childid");
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Tickets->new($CurrentUser);
$Collection->LimitMemberOf('');
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok ($has{$parentid} , "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


#  Do it all over with TicketSQL
#



# Now we find a collection of all the tickets which have no members. they should have no children.
$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL ("HasMember IS NULL");
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");
ok( $has{$childid}, "The collection has our child - $childid");


# Now we find a collection of all the tickets which have no members. they should have no children.
# Alternate syntax
$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("HasMember = ''");
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");
ok( $has{$childid}, "The collection has our child - $childid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("MemberOf IS NULL");
# must not  contain parent; must contain parent
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("MemberOf = ''");
# must not  contain parent; must contain parent
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


# Now we find a collection of all the tickets which are not members of the parent ticket
$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL("MemberOf != $parentid");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->LimitMemberOf($parentid, OPERATOR => '!=');
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");

my $grand_child_ticket = RT::Ticket->new( $CurrentUser );
my ($grand_childid) = $child_ticket->Create(
    Subject => 'test child',
    Queue   => $queue->Id,
    MemberOf => $childid,
);
ok($childid, "We created a grand child ticket");

my $unlinked_ticket = RT::Ticket->new( $CurrentUser );
my ($unlinked_id) = $child_ticket->Create(
    Subject => 'test unlinked',
    Queue   => $queue->Id,
);
ok($unlinked_id, "We created a grand child ticket");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedTo = $childid" );
is($Collection->Count,1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $grand_childid, "We found all tickets linked to ticket #$childid");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedFrom = $childid" );
is($Collection->Count,1, "We found only one result");
ok($Collection->First);
is($Collection->First->id, $parentid, "We found all tickets linked from ticket #$childid");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedTo IS NULL" );
ok($Collection->Count, "Result is set is not empty");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "parent is in collection");
ok( $has{$unlinked_id}, "unlinked is in collection");
ok( !$has{$childid}, "child is NOT in collection");
ok( !$has{$grand_childid}, "grand child too is not in collection");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedTo IS NOT NULL" );
ok($Collection->Count, "Result set is not empty");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection has no our parent - $parentid");
ok( !$has{$unlinked_id}, "unlinked is not in collection");
ok( $has{$childid}, "The collection have our child - $childid");
ok( $has{$grand_childid}, "The collection have our grand child - $grand_childid");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedFrom IS NULL" );
ok($Collection->Count, "Result is set is not empty");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "parent is NOT in collection");
ok( !$has{$childid}, "child is NOT in collection");
ok( $has{$grand_childid}, "grand child is in collection");
ok( $has{$unlinked_id}, "unlinked is in collection");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "LinkedFrom IS NOT NULL" );
ok($Collection->Count, "Result set is not empty");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( $has{$childid}, "The collection have our child - $childid");
ok( !$has{$grand_childid}, "The collection have no our grand child - $grand_childid");
ok( !$has{$unlinked_id}, "unlinked is not in collection");

$Collection = RT::Tickets->new($CurrentUser);
$Collection->FromSQL( "Linked = $childid" );
is($Collection->Count, 2, "We found two tickets: parent and child");
%has = ();
while (my $t = $Collection->Next) {
    ++$has{$t->id};
}
ok( !$has{$childid}, "Ticket is not linked to itself");
ok( $has{$parentid}, "The collection has our parent");
ok( $has{$grand_childid}, "The collection have our child");
ok( !$has{$unlinked_id}, "unlinked is not in collection");

