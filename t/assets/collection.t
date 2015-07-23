use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $user = RT::Test->load_or_create_user( Name => 'testuser' );
ok $user->id, "Created user";

my $catalog  = create_catalog( Name => "BPS" );
ok $catalog && $catalog->id, "Created catalog";

my $location = create_cf( Name => 'Location' );
ok $location->id, "Created CF";
ok apply_cfs($location), "Applied CF";

ok(
    create_assets(
        { Name => "Thinkpad T420s", Catalog => $catalog->id, "CustomField-Location" => "Home" },
        { Name => "Standing desk",  Catalog => $catalog->id, "CustomField-Location" => "Office" },
        { Name => "Chair",          Catalog => $catalog->id, "CustomField-Location" => "Office" },
    ),
    "Created assets"
);

diag "Mark chair as deleted";
{
    my $asset = RT::Asset->new( RT->SystemUser );
    $asset->LoadByCols( Name => "Chair" );
    my ($ok, $msg) = $asset->SetStatus( "deleted" );
    ok($ok, "Deleted the chair: $msg");
}

diag "Basic types of limits";
{
    my $assets = RT::Assets->new( RT->SystemUser );
    $assets->Limit( FIELD => 'Name', OPERATOR => 'LIKE', VALUE => 'thinkpad' );
    is $assets->Count, 1, "Found 1 like thinkpad";
    is $assets->First->Name, "Thinkpad T420s";

    $assets = RT::Assets->new( RT->SystemUser );
    $assets->UnLimit;
    is $assets->Count, 2, "Found 2 total";
    ok((!grep { $_->Name eq "Chair" } @{$assets->ItemsArrayRef}), "No chair (disabled)");

    $assets = RT::Assets->new( RT->SystemUser );
    $assets->Limit( FIELD => 'Status', VALUE => 'deleted' );
    $assets->{allow_deleted_search} = 1;
    is $assets->Count, 1, "Found 1 deleted";
    is $assets->First->Name, "Chair", "Found chair";

    $assets = RT::Assets->new( RT->SystemUser );
    $assets->UnLimit;
    $assets->LimitCustomField(
        CUSTOMFIELD => $location->id,
        VALUE       => "Office",
    );
    is $assets->Count, 1, "Found 1 in Office";
    ok $assets->First, "Got record";
    is $assets->First->Name, "Standing desk", "Found standing desk";
}

diag "Test ACLs";
{
    my $assets = RT::Assets->new( RT::CurrentUser->new($user) );
    $assets->UnLimit;
    is scalar @{$assets->ItemsArrayRef}, 0, "Found none";
}

done_testing;
