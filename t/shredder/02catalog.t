use strict;
use warnings;

use Test::Deep;

use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";


diag 'simple catalog' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $catalog = RT::Catalog->new( RT->SystemUser );
    my ( $id, $msg ) = $catalog->Create( Name => 'my catalog' );
    ok( $id, 'created catalog' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $catalog );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'catalog with a right granted' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $catalog = RT::Catalog->new( RT->SystemUser );
    my ( $id, $msg ) = $catalog->Create( Name => 'my catalog' );
    ok( $id, 'created catalog' ) or diag "error: $msg";

    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup('Everyone');
    ok( $group->id, 'loaded group' );

    ( $id, $msg ) = $group->PrincipalObj->GrantRight(
        Right  => 'CreateAsset',
        Object => $catalog,
    );
    ok( $id, 'granted right' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $catalog );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'catalog with a watcher' if $ENV{TEST_VERBOSE};
{
    my $group = RT::Group->new( RT->SystemUser );
    my ( $id, $msg ) = $group->CreateUserDefinedGroup( Name => 'my group' );
    ok( $id, 'created group' ) or diag "error: $msg";

    $test->create_savepoint('bqcreate');
    my $catalog = RT::Catalog->new( RT->SystemUser );
    ( $id, $msg ) = $catalog->Create( Name => 'my catalog' );
    ok( $id, 'created catalog' ) or diag "error: $msg";

    ( $id, $msg ) = $catalog->AddRoleMember(
        Type        => 'Contact',
        PrincipalId => $group->id,
    );
    ok( $id, 'added watcher' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $catalog );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('bqcreate'), "current DB equal to savepoint" );
}

diag 'catalog with custom fields' if $ENV{TEST_VERBOSE};
{
    my $asset_custom_field = RT::CustomField->new( RT->SystemUser );
    my ( $id, $msg ) = $asset_custom_field->Create(
        Name       => 'asset custom field',
        Type       => 'Freeform',
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok( $id, 'created asset custom field' ) or diag "error: $msg";

    my $catalog_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $catalog_custom_field->Create(
        Name       => 'catalog custom field',
        Type       => 'Freeform',
        LookupType => RT::Catalog->CustomFieldLookupType,
        MaxValues  => '1',
    );
    ok( $id, 'created catalog custom field' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $catalog = RT::Catalog->new( RT->SystemUser );
    ( $id, $msg ) = $catalog->Create( Name => 'my catalog' );
    ok( $id, 'created catalog' ) or diag "error: $msg";

    # apply the custom fields to the catalog.
    ( $id, $msg ) = $asset_custom_field->AddToObject($catalog);
    ok( $id, 'applied asset cf to catalog' ) or diag "error: $msg";

    ( $id, $msg ) = $catalog_custom_field->AddToObject($catalog);
    ok( $id, 'applied catalog cf to catalog' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $catalog );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing;
