use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
use RT::Test::Web;
use Test::Warn;

use RT::Link;
my $link = RT::Link->new(RT->SystemUser);

ok (ref $link);
isa_ok( $link, 'RT::Link');
isa_ok( $link, 'RT::Base');
isa_ok( $link, 'RT::Record');
isa_ok( $link, 'DBIx::SearchBuilder::Record');

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

my $parent = RT::Ticket->new(RT->SystemUser);
my ($pid, undef, $msg) = $parent->Create(
    Queue   => $queue->id,
    Subject => 'parent',
);
ok $pid, 'created a ticket #'. $pid or diag "error: $msg";

my $child = RT::Ticket->new(RT->SystemUser);
((my $cid), undef, $msg) = $child->Create(
    Queue   => $queue->id,
    Subject => 'child',
);
ok $cid, 'created a ticket #'. $cid or diag "error: $msg";

{
    my ($status, $msg);
    clean_links();

    ($status, $msg) = $parent->AddLink;
    ok(!$status, "didn't create a link: $msg");

    warning_like {
        ($status, $msg) = $parent->AddLink( Base => $parent->id );
    } qr/Can't link a ticket to itself/, "warned about linking a ticket to itself";
    ok(!$status, "didn't create a link: $msg");

    warning_like {
        ($status, $msg) = $parent->AddLink( Base => $parent->id, Type => 'HasMember' );
    } qr/Can't link a ticket to itself/, "warned about linking a ticket to itself";
    ok(!$status, "didn't create a link: $msg");
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->URI,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => 't:'. $child->id,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    $child->SetStatus('deleted');

    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok(!$status, "can't link to deleted ticket: $msg");

    $child->SetStatus('new');
    ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok($status, "created a link: $msg");

    $child->SetStatus('deleted');
    my $children = $parent->Members;
    $children->RedoSearch;

    my $total = 0;
    $total++ while $children->Next;
    is( $total, 0, 'Next skips deleted tickets' );

    is( @{ $children->ItemsArrayRef },
        0, 'ItemsArrayRef skips deleted tickets' );

    # back to active status
    $child->SetStatus('new');
}

diag 'Test methods that return all links recursively';
{
    my ($level1, $level2, $level3, $extra) = RT::Test->create_tickets( { },  map { { Subject => "Test $_" } } ( 1 .. 4 ) );
    ok( $level1->Id, "Got a new ticket Id " . $level1->Id );
    ok( $level2->Id, "Got a new ticket Id " . $level2->Id );
    ok( $level3->Id, "Got a new ticket Id " . $level3->Id );

    my ($status, $msg);
    # Links from 1 to 2
    ($status, $msg) = $level1->AddLink(
        Type => 'MemberOf', Base => 't:' . $level2->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level1->AddLink(
        Type => 'DependsOn', Target => 't:' . $level2->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level1->AddLink(
        Type => 'RefersTo', Target => 't:' . $level2->Id,
    );
    ok($status, "created a link: $msg");

    # Links from 2 to 3
    ($status, $msg) = $level2->AddLink(
        Type => 'MemberOf', Base => 't:' . $level3->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level2->AddLink(
        Type => 'DependsOn', Target => 't:' . $level3->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level2->AddLink(
        Type => 'RefersTo', Target => 't:' . $level3->Id,
    );
    ok($status, "created a link: $msg");

    foreach my $method ( qw(AllDependsOn AllMembers AllRefersTo) ) {
        my @linked = $level1->$method;
        is( scalar @linked, 2, "For level 1 ticket, found two links for $method");
    }

    foreach my $method ( qw(AllDependedOnBy AllMembersOf AllReferredToBy) ) {
        my @linked = $level3->$method;
        is( scalar @linked, 2, "For level 3 ticket, found two links for $method");
    }

    # Links from 1 to 2
    ($status, $msg) = $level2->AddLink(
        Type => 'MemberOf', Base => 't:' . $extra->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level2->AddLink(
        Type => 'DependsOn', Target => 't:' . $extra->Id,
    );
    ok($status, "created a link: $msg");
    ($status, $msg) = $level2->AddLink(
        Type => 'RefersTo', Target => 't:' . $extra->Id,
    );
    ok($status, "created a link: $msg");

    foreach my $method ( qw(AllDependsOn AllMembers AllRefersTo) ) {
        my @linked = $level1->$method;
        is( scalar @linked, 3, "For level 1 ticket, now three links for $method");
    }

}

{
    my ($status, $msg) = $child->SetStatus('resolved');
    ok($status, "resolved the child: $msg");

    my ($active, $inactive) = RT::Links->SortByActivityType($child, $parent);
    is_deeply([map { $_->id } @$active],   [$parent->id], 'parent is active');
    is_deeply([map { $_->id } @$inactive], [$child->id],  'child is inactive');
}

{
    diag "Link listings leave out reminders, deleted tickets and records the user can't see";

    my $ticket   = RT::Test->create_ticket( Queue => 'General', Subject => 'listing ticket' );
    my $reminder = RT::Test->create_ticket( Queue => 'General', Subject => 'listing reminder', Type => 'reminder' );
    ok( $reminder->AddLink( Type => 'RefersTo', Target => $ticket->id ), 'the reminder refers to the ticket' );

    my $count = sub {
        my $user = shift || RT->SystemUser;
        my $object = RT::Ticket->new($user);
        $object->Load( $ticket->id );
        return RT::Links->LinkListingCount( CurrentUser => $user, Object => $object );
    };
    is( $ticket->ReferredToBy->Count, 1, 'the reminder link is in the raw links' );
    is( $count->(), 0, 'a reminder is not counted' );

    my $referrer = RT::Test->create_ticket( Queue => 'General', Subject => 'listing referrer' );
    ok( $referrer->AddLink( Type => 'RefersTo', Target => $ticket->id ), 'another ticket refers to the ticket' );
    my $listing = RT::Links->FilterLinkListing(
        CurrentUser      => RT->SystemUser,
        Class            => 'RT::Ticket',
        Ids              => [ $reminder->id, $referrer->id ],
        RelationshipType => 'ReferredToBy',
    );
    is_deeply( [ map { $_->id } @{ $listing->ItemsArrayRef } ], [ $referrer->id ], 'ReferredToBy listing leaves out the reminder' );
    is( $count->(), 1, 'a referring ticket is counted' );

    ok( $ticket->AddLink( Type => 'RefersTo', Target => 'https://example.com/listing' ), 'linked a URL' );
    is( $count->(), 2, 'a URL is counted' );

    my $deleted = RT::Test->create_ticket( Queue => 'General', Subject => 'listing deleted' );
    ok( $ticket->AddLink( Type => 'DependsOn', Target => $deleted->id ), 'linked a ticket to delete' );
    is( $count->(), 3, 'the dependency is counted' );
    my ( $ok, $msg ) = $deleted->SetStatus('deleted');
    ok( $ok, "deleted the dependency: $msg" );
    is( $count->(), 2, 'a deleted ticket is not counted' );

    my $hidden_queue = RT::Test->load_or_create_queue( Name => 'Listing hidden' );
    my $hidden = RT::Test->create_ticket( Queue => $hidden_queue->id, Subject => 'listing hidden' );
    ok( $ticket->AddLink( Type => 'DependsOn', Target => $hidden->id ), 'linked a ticket in another queue' );
    my $viewer = RT::Test->load_or_create_user( Name => 'listing-viewer' );
    ok( RT::Test->add_rights( { Principal => $viewer, Right => [qw(ShowTicket SeeQueue)], Object => $queue } ),
        'viewer can see General only' );
    is( $count->(), 3, 'the other queue ticket is counted for the system user' );
    is( $count->( RT::CurrentUser->new($viewer) ), 2, 'a ticket the viewer cannot see is not counted for the viewer' );
}

{
    diag "Link messages name local non-ticket objects by type and id";
    clean_links();

    my $catalog = RT::Catalog->new( RT->SystemUser );
    my ( $ok, $msg ) = $catalog->Create( Name => 'Link messages' );
    ok( $ok, "created a catalog: $msg" );
    my $asset = RT::Asset->new( RT->SystemUser );
    ( $ok, $msg ) = $asset->Create( Name => 'LT-057', Catalog => $catalog->id );
    ok( $ok, "created an asset: $msg" );
    my $user = RT::Test->load_or_create_user( Name => 'link-message-user' );

    my ( $status, $text ) = $parent->AddLink( Type => 'RefersTo', Base => 'asset:' . $asset->id );
    ok( $status, 'linked an asset' );
    is( $text, 'Asset ' . $asset->id . ' refers to Ticket ' . $parent->id . '.', 'add message names the asset' );

    ( $status, $text ) = $parent->AddLink( Type => 'RefersTo', Target => 'user:' . $user->id );
    ok( $status, 'linked a user' );
    is( $text, 'Ticket ' . $parent->id . ' refers to User ' . $user->id . '.', 'add message names the user' );

    ( $status, $text ) = $parent->DeleteLink( Type => 'RefersTo', Base => 'asset:' . $asset->id );
    ok( $status, 'removed the asset link' );
    is( $text, 'Asset ' . $asset->id . ' no longer refers to Ticket ' . $parent->id . '.', 'delete message names the asset' );

    ( $status, $text ) = $parent->AddLink( Type => 'RefersTo', Target => 'https://example.com/doc' );
    ok( $status, 'linked an external URL' );
    is( $text, 'Ticket ' . $parent->id . ' refers to URI https://example.com/doc.', 'external links keep the URI' );

    clean_links();
}

done_testing();

sub clean_links {
    my $links = RT::Links->new( RT->SystemUser );
    $links->UnLimit;
    while ( my $link = $links->Next ) {
        my ($status, $msg) = $link->Delete;
        $RT::Logger->error("Couldn't delete a link: $msg")
            unless $status;
    }
}

