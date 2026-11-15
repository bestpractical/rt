use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->db_is_valid;

my $class = RT::Class->new( RT->SystemUser );
my ( $id, $msg ) = $class->Create( Name => 'ValidatorTopics' );
ok( $id, "Created class: $msg" );

sub create_topic {
    my %args  = @_;
    my $topic = RT::Topic->new( RT->SystemUser );
    my ( $id, $msg ) = $topic->Create(
        ObjectType => 'RT::Class',
        ObjectId   => $class->Id,
        Parent     => 0,
        %args,
    );
    ok( $id, "Created topic $args{Name}: $msg" );
    return $topic;
}

sub object_topic_count {
    my $topic_id = shift;
    my $object_topics = RT::ObjectTopics->new( RT->SystemUser );
    $object_topics->LimitToTopic($topic_id);
    return $object_topics->Count;
}

diag "rt-validator deletes ObjectTopics rows that reference a missing topic";
{
    my $topic = create_topic( Name => 'ValidatorOrphan' );

    my $article = RT::Article->new( RT->SystemUser );
    my ( $id, $msg ) = $article->Create( Class => $class->Id, Name => 'ValidatorOrphanArticle' );
    ok( $id, "Created article: $msg" );
    ( $id, $msg ) = $article->AddTopic( Topic => $topic->Id );
    ok( $id, "Added topic to article: $msg" );

    my $topic_id = $topic->Id;
    my $object_topic_id = $article->Topics->First->Id;

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Topics WHERE id = ?", undef, $topic_id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'rt-validator exits non-zero' );
    like(
        $res,
        qr/^Record #$object_topic_id in ObjectTopics references a nonexistent record in Topics$/m,
        'rt-validator reports the orphaned ObjectTopics row'
    );
    is( object_topic_count($topic_id), 0, 'rt-validator deleted the orphaned ObjectTopics row' );

    RT::Test->db_is_valid;
}

diag "rt-validator moves topics with a missing parent to the top level";
{
    my $parent = create_topic( Name => 'ValidatorMissingParent' );
    my $child  = create_topic( Name => 'ValidatorOrphanChild', Parent => $parent->Id );
    my $child_id = $child->Id;

    RT::Test->db_is_valid;

    $RT::Handle->dbh->do( "DELETE FROM Topics WHERE id = ?", undef, $parent->Id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'rt-validator exits non-zero' );
    like(
        $res,
        qr/^Record #$child_id in Topics references a nonexistent record in Topics$/m,
        'rt-validator reports the topic with a missing parent'
    );

    my $reparented = RT::Topic->new( RT->SystemUser );
    $reparented->Load($child_id);
    is( $reparented->Id,     $child_id, 'Child topic still exists' );
    is( $reparented->Parent, 0,         'Child topic is now a top-level topic' );

    RT::Test->db_is_valid;
}

done_testing();
