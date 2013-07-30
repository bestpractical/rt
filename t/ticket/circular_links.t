use strict;
use warnings;

use RT::Test tests => undef;

my ( $foo, $bar, $baz ) = RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'foo' },
    { Subject => 'bar' },
    { Subject => 'baz' }
);

diag "test circular DependsOn";
my ( $status, $msg ) = $foo->AddLink( Type => 'DependsOn', Target => $bar->id );
ok( $status, "foo depends on bar" );
( $status, $msg ) = $foo->AddLink( Type => 'DependsOn', Base => $bar->id );
ok( !$status, "foo can't be depended on bar" );
( $status, $msg ) = $bar->AddLink( Type => 'DependsOn', Target => $foo->id );
ok( !$status, "bar can't depend on foo back" );
( $status, $msg ) = $bar->AddLink( Type => 'DependsOn', Target => $baz->id );
ok( $status, "bar depends on baz" );
( $status, $msg ) = $baz->AddLink( Type => 'DependsOn', Target => $foo->id );
ok( !$status, "baz can't depend on foo back" );


diag "test circular MemberOf";
( $status, $msg ) = $foo->AddLink( Type => 'MemberOf', Target => $bar->id );
ok( $status, "foo is a member of bar" );
( $status, $msg ) = $foo->AddLink( Type => 'MemberOf', Base => $bar->id );
ok( !$status, "foo can't have member bar" );
( $status, $msg ) = $bar->AddLink( Type => 'MemberOf', Target => $foo->id );
ok( !$status, "bar can't be a member of foo" );
( $status, $msg ) = $bar->AddLink( Type => 'MemberOf', Target => $baz->id );
ok( $status, "baz is a member of bar" );
( $status, $msg ) = $baz->AddLink( Type => 'DependsOn', Target => $foo->id );
ok( !$status, "baz can't be a member of foo" );


diag "test circular RefersTo";
( $status, $msg ) = $foo->AddLink( Type => 'RefersTo', Target => $bar->id );
ok( $status, "foo refers to bar" );
( $status, $msg ) = $foo->AddLink( Type => 'RefersTo', Base => $bar->id );
ok( $status, "foo can be referred to by bar" );

done_testing;
