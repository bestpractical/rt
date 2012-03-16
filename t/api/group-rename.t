
use strict;
use warnings;
use RT;
use RT::Test nodata => 1, tests => undef;



{
    my $u = RT::Group->new(RT->SystemUser);
    my ( $id, $msg ) = $u->CreateUserDefinedGroup( Name => 'TestGroup' );
    ok( $u->id, 'Created TestGroup' );
    ok( $u->SetName('testgroup'), 'rename to lower cased version: testgroup' );
    ok( $u->SetName('TestGroup'), 'rename back' );

    my $u2 = RT::Group->new( RT->SystemUser );
    ( $id, $msg ) = $u2->CreateUserDefinedGroup( Name => 'TestGroup' );
    ok( !$id, "can't create duplicated group: $msg" );
    ( $id, $msg ) = $u2->CreateUserDefinedGroup( Name => 'testgroup' );
    ok( !$id, "can't create duplicated group even case is different: $msg" );
}

done_testing;
