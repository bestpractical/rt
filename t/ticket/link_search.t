#!/usr/bin/perl -w

use Test::More tests => 63;
use strict;
use RT;

# Load the config file
use RT::Test;

#Connect to the database and get RT::SystemUser and RT::Nobody loaded


#Get the current user all loaded
my $CurrentUser = $RT::SystemUser;

my $queue = new RT::Model::Queue($CurrentUser);
$queue->load('General') || Abort(loc("Queue could not be loaded."));

my $child_ticket = new RT::Model::Ticket( $CurrentUser );
my ($childid) = $child_ticket->create(
    Subject => 'test child',
    Queue => $queue->id,
);
ok($childid, "We Created a child ticket");

my $parent_ticket = new RT::Model::Ticket( $CurrentUser );
my ($parentid) = $parent_ticket->create(
    Subject => 'test parent',
    Children => [ $childid ],
    Queue => $queue->id,
);
ok($parentid, "We Created a parent ticket");


my $Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->limit_member_of( $parentid );
is($Collection->count,1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $childid, "We found the collection of all children of $parentid with Limit");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("MemberOf = $parentid");
is($Collection->count, 1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $childid, "We found the collection of all children of $parentid with TicketSQL");


$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->limit_has_member ($childid);
is($Collection->count,1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $parentid, "We found the collection of all parents of $childid with Limit");


$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("has_member = $childid");
is($Collection->count,1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $parentid, "We found the collection of all parents of $childid with TicketSQL");


# Now we find a collection of all the tickets which have no members. they should have no children.
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->limit_has_member('');
# must contain child; must not contain parent
my %has;
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$childid}, "The collection has our child - $childid");
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->limit_member_of('');
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok ($has{$parentid} , "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


#  Do it all over with TicketSQL
#



# Now we find a collection of all the tickets which have no members. they should have no children.
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql ("has_member IS NULL");
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");
ok( $has{$childid}, "The collection has our child - $childid");


# Now we find a collection of all the tickets which have no members. they should have no children.
# Alternate syntax
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("has_member = ''");
# must contain parent; must not contain child
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection doesn't have our parent - $parentid");
ok( $has{$childid}, "The collection has our child - $childid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("MemberOf IS NULL");
# must not  contain parent; must contain parent
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


# Now we find a collection of all the tickets which are not members of anything. they should have no parents.
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("MemberOf = ''");
# must not  contain parent; must contain parent
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");


# Now we find a collection of all the tickets which are not members of the parent ticket
$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql("MemberOf != $parentid");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->limit_member_of($parentid, operator => '!=');
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( !$has{$childid}, "The collection doesn't have our child - $childid");

my $grand_child_ticket = new RT::Model::Ticket( $CurrentUser );
my ($grand_childid) = $child_ticket->create(
    Subject => 'test child',
    Queue   => $queue->id,
    MemberOf => $childid,
);
ok($childid, "We Created a grand child ticket");

my $unlinked_ticket = new RT::Model::Ticket( $CurrentUser );
my ($unlinked_id) = $child_ticket->create(
    Subject => 'test unlinked',
    Queue   => $queue->id,
);
ok($unlinked_id, "We Created a grand child ticket");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedTo = $childid" );
is($Collection->count,1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $grand_childid, "We found all tickets linked to ticket #$childid");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedFrom = $childid" );
is($Collection->count,1, "We found only one result");
ok($Collection->first);
is($Collection->first->id, $parentid, "We found all tickets linked from ticket #$childid");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedTo IS NULL" );
ok($Collection->count, "Result is set is not empty");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "parent is in collection");
ok( $has{$unlinked_id}, "unlinked is in collection");
ok( !$has{$childid}, "child is NOT in collection");
ok( !$has{$grand_childid}, "grand child too is not in collection");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedTo IS NOT NULL" );
ok($Collection->count, "Result set is not empty");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "The collection has no our parent - $parentid");
ok( !$has{$unlinked_id}, "unlinked is not in collection");
ok( $has{$childid}, "The collection have our child - $childid");
ok( $has{$grand_childid}, "The collection have our grand child - $grand_childid");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedFrom IS NULL" );
ok($Collection->count, "Result is set is not empty");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( !$has{$parentid}, "parent is NOT in collection");
ok( !$has{$childid}, "child is NOT in collection");
ok( $has{$grand_childid}, "grand child is in collection");
ok( $has{$unlinked_id}, "unlinked is in collection");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "LinkedFrom IS NOT NULL" );
ok($Collection->count, "Result set is not empty");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( $has{$parentid}, "The collection has our parent - $parentid");
ok( $has{$childid}, "The collection have our child - $childid");
ok( !$has{$grand_childid}, "The collection have no our grand child - $grand_childid");
ok( !$has{$unlinked_id}, "unlinked is not in collection");

$Collection = RT::Model::TicketCollection->new(current_user => );
$Collection->from_sql( "Linked = $childid" );
is($Collection->count, 2, "We found two tickets: parent and child");
%has = ();
while (my $t = $Collection->next) {
    ++$has{$t->id};
}
ok( !$has{$childid}, "Ticket is not linked to itself");
ok( $has{$parentid}, "The collection has our parent");
ok( $has{$grand_childid}, "The collection have our child");
ok( !$has{$unlinked_id}, "unlinked is not in collection");


1;
