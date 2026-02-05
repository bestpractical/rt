
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

$test->create_savepoint('clean');

my $queue = RT::Queue->new( RT->SystemUser );
my ($qid) = $queue->Load( 'General' );
ok( $qid, "loaded queue" );

my $ticket = RT::Ticket->new( RT->SystemUser );
my ($tid) = $ticket->Create( Queue => $qid, Subject => 'test' );
ok( $tid, "ticket created" );

my $config = RT::Configuration->new( RT->SystemUser );
ok( $config->Create( Name => 'RememberDefaultQueue', Content => 1 ) );

my $auth_token = RT::AuthToken->new( RT->SystemUser );
ok( $auth_token->Create( Owner => RT->SystemUser->Id, Description => 'test' ) );

my $shortener = RT::Shortener->new( RT->SystemUser );
ok( $shortener->Create( Content => 'Query=id>1' ) );

$test->create_savepoint('bucreate'); # berfore user create
my $user = RT::User->new( RT->SystemUser );
my ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
ok( $uid, "created new user" ) or diag "error: $msg";
is( $user->id, $uid, "id is correct" );
# HACK: set props to enable VARIABLE dependencies
$ticket->__Set( Field => 'LastUpdatedBy', Value => $uid );
$config->__Set( Field => $_, Value => $uid ) for qw/Creator LastUpdatedBy/;
$auth_token->__Set( Field => $_, Value => $uid ) for qw/Creator LastUpdatedBy/;
$shortener->__Set( Field => $_, Value => $uid ) for qw/Creator LastUpdatedBy LastAccessedBy/;

$test->create_savepoint('aucreate'); # after user create

{
    my $resolver = sub {
        my %args = (@_);
        my $t = $args{'TargetObject'};
        my $resolver_uid = RT->SystemUser->id;
        foreach my $method ( qw(Creator LastUpdatedBy LastAccessedBy) ) {
            next unless $t->_Accessible( $method => 'read' );
            $t->__Set( Field => $method, Value => $resolver_uid );
        }
    };
    my $shredder = $test->shredder_new();
    $shredder->PutResolver( BaseClass => 'RT::User', Code => $resolver );
    $shredder->Wipeout( Object => $user );
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");
}

{
    $test->restore_savepoint('aucreate');
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($uid);
    ok($user->id, "loaded user after restore");
    my $shredder = $test->shredder_new();
    eval { $shredder->Wipeout( Object => $user ) };
    ok($@, "wipeout throw exception if no resolvers");
    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('aucreate'), "current DB equal to savepoint");
}

done_testing;
