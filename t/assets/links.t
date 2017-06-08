use strict;
use warnings;

use RT::Test::Assets tests => undef;
use Test::Warn;

my $catalog = create_catalog( Name => "BPS" );
ok $catalog && $catalog->id, "Created Catalog";

ok(
    create_assets(
        { Name => "Thinkpad T420s", Catalog => $catalog->id },
        { Name => "Standing desk", Catalog => $catalog->id },
        { Name => "Chair", Catalog => $catalog->id },
    ),
    "Created assets"
);

my $ticket = RT::Test->create_ticket(
    Queue   => 1,
    Subject => 'a test ticket',
);
ok $ticket->id, "Created ticket";

diag "RT::URI::asset";
{
    my %uris = (
        # URI                   => Asset Name
        "asset:1"               => { id => 1, Name => "Thinkpad T420s" },
        "asset:01"              => { id => 1, Name => "Thinkpad T420s" },
        "asset://example.com/2" => { id => 2, Name => "Standing desk" },
        "asset:13"              => undef,
    );

    while (my ($url, $expected) = each %uris) {
        my $uri = RT::URI->new( RT->SystemUser );
        if ($expected) {
            my $parsed = $uri->FromURI($url);
            ok $parsed, "Parsed $url";

            my $asset = $uri->Object;
            ok $asset, "Got object";
            is ref($asset), "RT::Asset", "... it's a RT::Asset";

            while (my ($field, $value) = each %$expected) {
                is $asset->$field, $value, "... $field is $value";
            }
        } else {
            my $parsed;
            warnings_like {
                $parsed = $uri->FromURI($url);
            } [qr/Unable to load asset/, qr/\Q$url\E/],
                "Caught warnings about unknown URI";
            ok !$parsed, "Failed to parse $url, as expected";
        }
    }
}

diag "RT::Asset link support";
{
    my $chair = RT::Asset->new( RT->SystemUser );
    $chair->LoadByCols( Name => "Chair" );
    ok $chair->id, "Loaded asset";
    is $chair->URI, "asset://example.com/".$chair->id, "->URI works";

    my ($link_id, $msg) = $chair->AddLink( Type => 'MemberOf', Target => 'asset:2' );
    ok $link_id, "Added link: $msg";

    my $parents = $chair->MemberOf;
    my $desk    = $parents->First->TargetObj;
    is $parents->Count, 1, "1 parent";
    is $desk->Name, "Standing desk", "Correct parent asset";

    for my $asset ($chair, $desk) {
        my $txns = $asset->Transactions;
        $txns->Limit( FIELD => 'Type', VALUE => 'AddLink' );
        is $txns->Count, 1, "1 AddLink txn on asset ".$asset->Name;
    }

    my ($ok, $err) = $chair->DeleteLink( Type => 'MemberOf', Target => 'asset:1' );
    ok !$ok, "Delete link failed on non-existent: $err";

    my ($deleted, $delete_msg) = $chair->DeleteLink( Type => 'MemberOf', Target => $parents->First->Target );
    ok $deleted, "Deleted link: $delete_msg";

    for my $asset ($chair, $desk) {
        my $txns = $asset->Transactions;
        $txns->Limit( FIELD => 'Type', VALUE => 'DeleteLink' );
        is $txns->Count, 1, "1 DeleteLink txn on asset ".$asset->Name;
    }
};

diag "Linking to tickets";
{
    my $laptop = RT::Asset->new( RT->SystemUser );
    $laptop->LoadByCols( Name => "Thinkpad T420s" );

    my ($ok, $msg) = $ticket->AddLink( Type => 'RefersTo', Target => $laptop->URI );
    ok $ok, "Ticket refers to asset: $msg";

    my $links = $laptop->ReferredToBy;
    is $links->Count, 1, "Found a ReferredToBy link via asset";

    ($ok, $msg) = $laptop->DeleteLink( Type => 'RefersTo', Base => $ticket->URI );
    ok $ok, "Deleted link from opposite side: $msg";
}

diag "Linking to tickets, asset leading zeros";
{
    my $laptop = RT::Asset->new( RT->SystemUser );
    $laptop->LoadByCols( Name => "Thinkpad T420s" );

    my ($ok, $msg) = $ticket->AddLink( Type => 'RefersTo', Target => 'asset:' . '0' . $laptop->Id );
    ok $ok, "Ticket refers to asset: $msg";

    my $links = $laptop->ReferredToBy;
    is $links->Count, 1, "Found a ReferredToBy link via asset";

    ($ok, $msg) = $laptop->DeleteLink( Type => 'RefersTo', Base => $ticket->URI );
    ok $ok, "Deleted link from opposite side: $msg";
}

diag "Links on ->Create";
{
    my $desk = RT::Asset->new( RT->SystemUser );
    $desk->LoadByCols( Name => "Standing desk" );
    ok $desk->id, "Loaded standing desk asset";

    my $asset = create_asset(
        Name            => "Anti-fatigue mat",
        Catalog         => $catalog->id,
        Parent          => $desk->URI,
        ReferredToBy    => [$ticket->id],
    );
    ok $asset->id, "Created asset with Parent link";

    my $parents = $asset->MemberOf;
    is $parents->Count, 1, "Found one Parent";
    is $parents->First->Target, $desk->URI, "... it's a desk!";

    my $referrals = $asset->ReferredToBy;
    is $referrals->Count, 1, "Found one ReferredToBy";
    is $referrals->First->Base, $ticket->URI, "... it's the ticket!";
}

done_testing;
