use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

my $class = RT::Class->new( RT->SystemUser );
$class->Load('General');
ok( $class->Id, 'loaded class General' );

diag 'simple article' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');

    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => $class->Id, Name => 'test 1' );
    ok( $id, 'created article' ) or diag "error: $msg";
    $article->ApplyTransactionBatch;

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $article );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'article with custom fields' if $ENV{TEST_VERBOSE};
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ( $id, $msg ) = $cf->Create(
        Name       => 'article custom field',
        Type       => 'Freeform',
        LookupType => RT::Article->CustomFieldLookupType,
        MaxValues  => 1,
    );
    ok( $id, 'created article custom field' ) or diag "error: $msg";

    # apply the custom fields to the class.
    ( $id, $msg ) = $cf->AddToObject($class);
    ok( $id, 'applied cf to class' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $article = RT::Article->new( RT->SystemUser );
    ( $id, $msg ) = $article->Create( Class => $class->Id, Name => 'test 1', 'CustomField-' . $cf->Id => 'test' );
    ok( $id, 'created article' ) or diag "error: $msg";
    is( $article->FirstCustomFieldValue('article custom field'), 'test', 'article cf is set' );
    $article->ApplyTransactionBatch;

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $article );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'article with topics' if $ENV{TEST_VERBOSE};
{
    my $topic = RT::Topic->new( RT->SystemUser );
    my ( $id, $msg ) = $topic->Create( ObjectType => 'RT::Class', ObjectId => $class->Id );
    ok( $id, 'created topic' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $article = RT::Article->new( RT->SystemUser );
    ( $id, $msg ) = $article->Create( Class => $class->Id, Name => 'test 1', 'Topics' => [ $topic->Id ] );
    ok( $id, 'created article' ) or diag "error: $msg";
    is( $article->Topics->First->Id, $topic->Id, 'article topic is set' );
    $article->ApplyTransactionBatch;

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $article );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing;
