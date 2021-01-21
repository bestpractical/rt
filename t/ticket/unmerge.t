use strict;
use warnings;

use RT::Test tests => 19;

# Load $CurrentUser
my $CurrentUser = RT->SystemUser;

my $queue = RT::Queue->new($CurrentUser);
$queue->Load('General') || Abort(loc("Queue could not be loaded."));

my $main_ticket = RT::Ticket->new( $CurrentUser );
my ($main_id) = $main_ticket->Create( Subject => 'test main', Queue => $queue->Id,);
ok($main_id, "main ticket created");

# init
my $to_merge_ticket = RT::Ticket->new( $CurrentUser );
my ($to_merge_id) = $to_merge_ticket->Create( Subject => 'test to merge', Queue => $queue->Id,);
ok($to_merge_id, "We created a ticket to be merged");

my $linked_ticket = RT::Ticket->new( $CurrentUser );
my ($linked_id) = $linked_ticket->Create( Subject => 'test linked', Queue => $queue->Id,);
ok($linked_id, "We created a linked ticket");
my( $link_id)= $linked_ticket->AddLink( Target => $to_merge_ticket->URI, Type => 'RefersTo');
ok($link_id, "Ticket is linked");

my $link_pre_merge= first_link( $linked_ticket);
is( $link_pre_merge->Target, $to_merge_ticket->URI, "link points to to_merge (pre-merge)");

# merge
my( $ok, $msg ) = $to_merge_ticket->MergeInto( $main_id);
ok($ok, "Ticket is merged: $msg");

is( $to_merge_ticket->Id, $main_id, "to_merge_ticket replaced by main_ticket after merge");
$to_merge_ticket->LoadById( $to_merge_id);
is( $to_merge_ticket->Id, $to_merge_id, "to_merge_ticket still exists");
is( $to_merge_ticket->EffectiveId, $main_id, "EffectiveId updated by merge");

my @merged= $main_ticket->Merged;
is( $merged[0], $to_merge_id, "to_merge in ->Merged");

my $linked_ticket_id = $linked_ticket->Id;
$linked_ticket = RT::Ticket->new( $CurrentUser );
( $ok, $msg ) = $linked_ticket->Load( $linked_ticket_id );
ok( $ok, "Reloaded linked ticket");
my $link_post_merge = first_link( $linked_ticket );
is( $link_post_merge->Target, $main_ticket->URI, "link now points to main");

# unmerge
$to_merge_ticket = RT::Ticket->new( $CurrentUser );
$to_merge_ticket->FlushCache;
( $ok, $msg ) = $to_merge_ticket->LoadById($to_merge_id);
ok( $ok, "Reloaded merged ticket $msg");

( $ok, $msg ) = $to_merge_ticket->UnmergeFrom( $main_ticket );
ok( $ok, "unmerge succeeded $msg");
$to_merge_ticket->FlushCache;

# Reload after unmerging, using regular Load method
my $unmerged = RT::Ticket->new( $CurrentUser );
( $ok, $msg ) = $unmerged->Load($to_merge_id);

ok( $ok, "Loaded unmerged ticket");
is( $unmerged->Id, $to_merge_id, "Id resolves to pre-merge id");
is( $unmerged->EffectiveId, $to_merge_id, "EffectiveId updated by unmerge");

$linked_ticket = RT::Ticket->new( $CurrentUser );
( $ok, $msg ) = $linked_ticket->Load( $linked_ticket_id );
ok( $ok, "Reloaded linked ticket");

my $link_post_unmerge = first_link( $linked_ticket);
is( $link_post_unmerge->Target, $unmerged->URI, "link now points to to_merge again");

done_testing();

sub first_link {
    my( $ticket, $direction, $type)= @_;
    $direction //= 'Base';
    $type      //= 'RefersTo';
    my $links = $ticket->_Links( $direction, $type);
    my $link  = $links->First;
    #$links->Last; # or subsequent calls to _links will return undef
    return $link;
}



