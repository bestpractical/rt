use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $catalog = create_catalog( Name => "A catalog" );
my $asset = create_asset( Name => "Test asset", Catalog => $catalog->id );
ok $asset && $asset->id, "Created asset";

for my $object ($asset, $catalog, RT->System) {
    for my $role (RT::Asset->Roles) {
        my $group = $object->RoleGroup($role);
        ok $group->id, "Loaded role group $role for " . ref($object);

        my $principal = $group->PrincipalObj;
        ok $principal && $principal->id, "Found PrincipalObj for role group"
            or next;

        if ($object->DOES("RT::Record::Role::Rights")) {
            my ($ok, $msg) = $principal->GrantRight(
                Object  => $object,
                Right   => "ShowAsset",
            );
            ok $ok, "Granted right" or diag "Error: $msg";
        }
    }
}

done_testing;
