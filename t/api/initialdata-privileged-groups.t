use strict;
use warnings;

use RT::Test tests => undef;

my $initialdata = RT::Test::get_relocatable_file( 'privileged-groups' => '..', 'data', 'initialdata' );
my ( $rv, $msg ) = RT->DatabaseHandle->InsertData( $initialdata, undef, disconnect_after => 0 );
ok( $rv, "Inserted test data: $msg" );

diag '@Members moves unprivileged user to Privileged';
{
    my $user = RT::User->new( RT->SystemUser );
    $user->Load('test_unpriv_to_priv');
    ok( $user->id,         'Loaded test_unpriv_to_priv' );
    ok( $user->Privileged, 'User is privileged' );
}

diag '@Members moves privileged user to Unprivileged';
{
    my $user = RT::User->new( RT->SystemUser );
    $user->Load('test_priv_to_unpriv');
    ok( $user->id,          'Loaded test_priv_to_unpriv' );
    ok( !$user->Privileged, 'User is unprivileged' );
}

diag '@Members does not put user in both groups';
{
    my $user = RT::User->new( RT->SystemUser );
    $user->Load('test_both_groups');
    ok( $user->id,          'Loaded test_both_groups' );
    ok( !$user->Privileged, 'User is unprivileged, not in both groups' );
}

RT::Test->db_is_valid;
done_testing;
