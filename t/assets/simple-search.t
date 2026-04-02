use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $catalog = create_catalog( Name => "General" );
ok $catalog && $catalog->Id, "Created catalog";

my $asset1 = create_asset( Name => "Laptop Alpha", Catalog => $catalog->Id );
ok $asset1->Id, "Created asset 1 (id=" . $asset1->Id . ")";

my $asset2 = create_asset( Name => "Laptop Beta", Catalog => $catalog->Id );
ok $asset2->Id, "Created asset 2 (id=" . $asset2->Id . ")";

my $asset3 = create_asset( Name => "Monitor Gamma", Catalog => $catalog->Id );
ok $asset3->Id, "Created asset 3 (id=" . $asset3->Id . ")";

diag "SimpleSearch by Name with LIKE";
{
    my $assets = RT::Assets->new( RT->SystemUser );
    $assets->SimpleSearch( Term => "Laptop", Catalog => $catalog );
    is $assets->Count, 2, "Found 2 assets matching 'Laptop'";
    is_deeply( [ map { $_->Id } @{ $assets->ItemsArrayRef } ], [ $asset1->Id, $asset2->Id ], 'Correct asset returned' );
}

diag "SimpleSearch by Name with no match";
{
    my $assets = RT::Assets->new( RT->SystemUser );
    $assets->SimpleSearch( Term => "Keyboard", Catalog => $catalog );
    is $assets->Count, 0, "Found 0 assets matching 'Keyboard'";
}

diag "SimpleSearch by id";
{
    my $id     = $asset1->Id;
    my $assets = RT::Assets->new( RT->SystemUser );
    $assets->SimpleSearch( Term => $id, Catalog => $catalog );
    is $assets->Count,     1,   "Found asset by exact id '$id'";
    is $assets->First->Id, $id, "Correct asset returned";
}

done_testing;
