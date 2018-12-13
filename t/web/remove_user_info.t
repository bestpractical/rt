use strict;
use warnings;

use RT::Test tests => undef;

RT::Config->Set( 'ShredderStoragePath', RT::Test->temp_directory . '' );

my ( $baseurl, $agent ) = RT::Test->started_ok;

diag("Test server running at $baseurl");
my $url = $agent->rt_base_url;

# Login
$agent->login( 'root' => 'password' );

# Anonymize User
{
    my %skip_clear = map { $_ => 1 } qw/Name Password AuthToken/;
    my @user_identifying_info
      = grep { !$skip_clear{$_} && RT::User->_Accessible( $_, 'write' ) } keys %{ RT::User->_CoreAccessible() };

    my $user = RT::Test->load_or_create_user(
        map( { $_ => 'test_string' } @user_identifying_info, 'AuthToken' ),
        Name         => 'Test User',
        EmailAddress => 'test@example.com',
    );
    ok( $user && $user->id );

    foreach my $attr (@user_identifying_info) {
        ok( $user->$attr, 'Attribute ' . $attr . ' is set' );
    }

    my $user_id = $user->id;

    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $user_id );
    $agent->follow_link_ok( { text => 'Anonymize User' } );

    $agent->submit_form_ok( { form_id => 'user-info-modal', }, "Anonymize user" );

    # UserId is still the same, but all other records should be anonimyzed for TestUser
    my ( $ret, $msg ) = $user->Load($user_id);
    ok($ret);

    like( $user->Name, qr/anon_/, 'Username replaced with anon name' );

    $user->Load($user_id);

    # Ensure that all other user fields are unset
    foreach my $attr (@user_identifying_info) {
        ok( !$user->$attr, 'Attribute ' . $attr . ' is unset' );
    }

    ok( !$user->HasPassword, 'Password is unset' );
    # Can't call AuthToken here because it creates new one automatically
    ok( !$user->_Value('AuthToken'), 'Authtoken is unset' );

    # Test that customfield values are removed with anonymize user action
    my $customfield = RT::CustomField->new( RT->SystemUser );
    ( $ret, $msg ) = $customfield->Create(
        Name       => 'TestCustomfield',
        LookupType => 'RT::User',
        Type       => 'FreeformSingle',
    );
    ok( $ret, $msg );

    ( $ret, $msg ) = $customfield->AddToObject($user);
    ok( $ret, "Added CF to user object - " . $msg );

    ( $ret, $msg ) = $user->AddCustomFieldValue(
        Field => 'TestCustomfield',
        Value => 'Testing'
    );
    ok( $ret, $msg );

    is( $user->FirstCustomFieldValue('TestCustomfield'), 'Testing', 'Customfield exists and has value for user.' );

    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $user->id );
    $agent->follow_link_ok( { text => 'Anonymize User' } );

    $agent->submit_form_ok(
        {   form_id => 'user-info-modal',
            fields  => { clear_customfields => 'On' },
        },
        "Anonymize user and customfields"
    );

    is( $user->FirstCustomFieldValue('TestCustomfield'), undef, 'Customfield value cleared' );
}

# Test replace user
{
    my $user = RT::Test->load_or_create_user(
        Name       => 'user',
        Password   => 'password',
        Privileged => 1
    );
    ok( $user && $user->id );
    my $id = $user->id;

    ok( RT::Test->set_rights( { Principal => $user, Right => [qw(SuperUser)] }, ), 'set rights' );

    ok( $agent->logout );
    ok( $agent->login( 'root' => 'password' ) );

    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $user->id );
    $agent->follow_link_ok( { text => 'Replace User' } );

    $agent->submit_form_ok(
        {   form_id => 'shredder-search-form',
            fields  => { WipeoutObject => 'RT::User-' . $user->Name, },
            button  => 'Wipeout'
        },
        "Replace user"
    );

    my ( $ret, $msg ) = $user->Load($id);

    is( $ret, 0, 'User successfully deleted with replace' );
}

done_testing();
