use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

my $catalog = RT::Catalog->new( RT->SystemUser );
$catalog->Load('General assets');
ok( $catalog->Id, 'loaded catalog General' );

diag 'simple asset' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');

    my $asset = RT::Asset->new( RT->SystemUser );
    my ( $id, $msg ) = $asset->Create( Catalog => $catalog->Id, Name => 'test 1' );
    ok( $id, 'created asset' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $asset );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'asset with custom fields' if $ENV{TEST_VERBOSE};
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ( $id, $msg ) = $cf->Create(
        Name       => 'asset custom field',
        Type       => 'Freeform',
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok( $id, 'created asset custom field' ) or diag "error: $msg";

    # apply the custom fields to the catalog.
    ( $id, $msg ) = $cf->AddToObject($catalog);
    ok( $id, 'applied cf to catalog' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $asset = RT::Asset->new( RT->SystemUser );
    ( $id, $msg ) = $asset->Create( Catalog => $catalog->Id, Name => 'test 1', 'CustomField-' . $cf->Id => 'test' );
    ok( $id, 'created asset' ) or diag "error: $msg";
    is( $asset->FirstCustomFieldValue('asset custom field'), 'test', 'asset cf is set' );

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $asset );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing;
