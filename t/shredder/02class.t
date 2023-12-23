use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

diag 'simple class' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $class = RT::Class->new( RT->SystemUser );
    my ( $id, $msg ) = $class->Create( Name => 'my class' );
    ok( $id, 'created class' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $class );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'class with a right granted' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');
    my $class = RT::Class->new( RT->SystemUser );
    my ( $id, $msg ) = $class->Create( Name => 'my class' );
    ok( $id, 'created class' ) or diag "error: $msg";

    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup('Everyone');
    ok( $group->id, 'loaded group' );

    ( $id, $msg ) = $group->PrincipalObj->GrantRight(
        Right  => 'CreateArticle',
        Object => $class,
    );
    ok( $id, 'granted right' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $class );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'class with custom fields' if $ENV{TEST_VERBOSE};
{
    my $class_custom_field = RT::CustomField->new( RT->SystemUser );
    my ( $id, $msg ) = $class_custom_field->Create(
        Name       => 'class custom field',
        Type       => 'Freeform',
        LookupType => RT::Class->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok( $id, 'created class custom field' ) or diag "error: $msg";

    my $article_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $article_custom_field->Create(
        Name       => 'article custom field',
        Type       => 'Freeform',
        LookupType => RT::Article->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok( $id, 'created article custom field' ) or diag "error: $msg";

    # Create an ObjectCustomField for assets with the same ObjectId, to make sure it's not shredded.
    my $asset_custom_field = RT::CustomField->new( RT->SystemUser );
    ( $id, $msg ) = $asset_custom_field->Create(
        Name       => 'asset custom field',
        Type       => 'Freeform',
        LookupType => RT::Asset->CustomFieldLookupType,
        MaxValues  => '1',
    );
    ok( $id, 'created asset custom field' ) or diag "error: $msg";

    my $catalog = RT::Catalog->new( RT->SystemUser );
    ok( $catalog->Create( Name => "catalog 2" ), "created catalog 2" );
    ( $id, $msg ) = $asset_custom_field->AddToObject($catalog);
    ok( $id, 'applied asset cf to catalog' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $class = RT::Class->new( RT->SystemUser );
    ( $id, $msg ) = $class->Create( Name => 'my class' );
    ok( $id, 'created class' ) or diag "error: $msg";

    # apply the custom fields to the class.
    ( $id, $msg ) = $class_custom_field->AddToObject($class);
    ok( $id, 'applied class cf to class' ) or diag "error: $msg";

    # apply the custom fields to the class.
    ( $id, $msg ) = $article_custom_field->AddToObject($class);
    ok( $id, 'applied article cf to class' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $class );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'class with articles' if $ENV{TEST_VERBOSE};
{

    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => 'General', Name => 'test 1' );
    ok( $id, 'created article' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $class = RT::Class->new( RT->SystemUser );
    ( $id, $msg ) = $class->Create( Name => 'my class' );
    ok( $id, 'created class' ) or diag "error: $msg";

    ( $id, $msg ) = $article->Create( Class => $class->Id, Name => 'test 2' );
    ok( $id, 'created article' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $class );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}


diag 'class with topics' if $ENV{TEST_VERBOSE};
{
    my $topic = RT::Topic->new( RT->SystemUser );
    my ( $id, $msg ) = $topic->Create( ObjectType => 'RT::Class', ObjectId => 0 );
    ok( $id, 'created topic' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $class = RT::Class->new( RT->SystemUser );
    ( $id, $msg ) = $class->Create( Name => 'my class' );
    ok( $id, 'created class' ) or diag "error: $msg";

    ( $id, $msg ) = $topic->Create( ObjectType => 'RT::Class', ObjectId => $class->Id );
    ok( $id, 'created topic' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $class );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing;
