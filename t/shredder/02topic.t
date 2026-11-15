use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

my $class = RT::Class->new( RT->SystemUser );
$class->Load('General');
ok( $class->Id, 'loaded class General' );

diag 'simple topic' if $ENV{TEST_VERBOSE};
{
    $test->create_savepoint('clean');

    my $topic = RT::Topic->new( RT->SystemUser );
    my ( $id, $msg ) = $topic->Create( ObjectType => 'RT::Class', ObjectId => $class->Id );
    ok( $id, 'created topic' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $topic );
    $shredder->WipeoutAll;
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'topic with articles' if $ENV{TEST_VERBOSE};
{
    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => 'General', Name => 'test 1' );
    ok( $id, 'created article' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $topic = RT::Topic->new( RT->SystemUser );
    ( $id, $msg ) = $topic->Create( ObjectType => 'RT::Class', ObjectId => $class->Id );
    ok( $id, 'created topic' ) or diag "error: $msg";

    ( $id, $msg ) = $article->AddTopic( Topic => $topic->Id );
    ok( $id, 'added topic' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $topic );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

diag 'topic with descendants linked to articles' if $ENV{TEST_VERBOSE};
{
    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => 'General', Name => 'test 2' );
    ok( $id, 'created article' ) or diag "error: $msg";

    $test->create_savepoint('clean');
    my $parent = RT::Topic->new( RT->SystemUser );
    ( $id, $msg ) = $parent->Create( ObjectType => 'RT::Class', ObjectId => $class->Id, Name => 'parent' );
    ok( $id, 'created parent topic' ) or diag "error: $msg";

    my $child = RT::Topic->new( RT->SystemUser );
    ( $id, $msg ) = $child->Create(
        ObjectType => 'RT::Class',
        ObjectId   => $class->Id,
        Name       => 'child',
        Parent     => $parent->Id,
    );
    ok( $id, 'created child topic' ) or diag "error: $msg";

    my $grandchild = RT::Topic->new( RT->SystemUser );
    ( $id, $msg ) = $grandchild->Create(
        ObjectType => 'RT::Class',
        ObjectId   => $class->Id,
        Name       => 'grandchild',
        Parent     => $child->Id,
    );
    ok( $id, 'created grandchild topic' ) or diag "error: $msg";

    ( $id, $msg ) = $article->AddTopic( Topic => $grandchild->Id );
    ok( $id, 'added grandchild topic to article' ) or diag "error: $msg";

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $parent );
    $shredder->WipeoutAll;
    $test->db_is_valid;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing;
