use strict;
use warnings;

BEGIN { require './t/lifecycles/utils.pl' }

diag "Test lifecycle name character validation";

# Test that invalid characters and long names are rejected
{
    my @invalid_names = (
        'test@lifecycle',     # @ symbol
        'test#lifecycle',     # hash
        'test$lifecycle',     # dollar sign
        'test%lifecycle',     # percent
        'test&lifecycle',     # ampersand
        'test*lifecycle',     # asterisk
        'test!lifecycle',     # exclamation
        'test+lifecycle',     # plus
        'test=lifecycle',     # equals
        'test.lifecycle',     # period
        'test,lifecycle',     # comma
        'test:lifecycle',     # colon
        'test;lifecycle',     # semicolon
        "test'lifecycle",     # single quote
        'test"lifecycle',     # double quote
        'test/lifecycle',     # forward slash
        'test\\lifecycle',    # backslash
        'test<lifecycle',     # less than
        'test>lifecycle',     # greater than
        'test(lifecycle',     # open paren
        'test)lifecycle',     # close paren
        'test[lifecycle',     # open bracket
        'test]lifecycle',     # close bracket
        'test{lifecycle',     # open brace
        'test}lifecycle',     # close brace
        't' x 33,             # 33 characters
    );

    for my $name (@invalid_names) {
        my ( $ok, $msg ) = RT::Lifecycle->CreateLifecycle(
            CurrentUser => RT->SystemUser,
            Name        => $name,
            Type        => 'ticket',
        );
        ok( !$ok, "Lifecycle name '$name' correctly rejected" );
        like(
            $msg,
            length $name > 32
            ? qr/has a maximum length of 32 characters/
            : qr/may only contain alphanumeric characters, underscores, dashes, and spaces/,
            "Got correct error message for '$name'"
        );
    }
}

diag "Test that valid lifecycle names are accepted";

# Test valid names with allowed special characters
{
    my @valid_names = (
        'test-lifecycle',       # dash
        'test_lifecycle',       # underscore
        'test lifecycle',       # space
        'Test-Lifecycle_123',   # mixed valid chars
        'My Custom Lifecycle',  # multiple spaces
        'lifecycle-with-many-dashes',
        'lifecycle_with_many_underscores',
        'UPPERCASE',
        'lowercase',
        'MixedCase123',
        't' x 32,
    );

    for my $name (@valid_names) {
        my ( $ok, $msg ) = RT::Lifecycle->CreateLifecycle(
            CurrentUser => RT->SystemUser,
            Name        => $name,
            Type        => 'ticket',
        );
        ok( $ok, "Lifecycle name '$name' accepted" ) or diag "Error: $msg";

        # Clean up - delete the lifecycle we just created
        RT->Config->RefreshConfigFromDatabase();
        RT::Lifecycle->FillCache();

        my ( $del_ok, $del_msg ) = RT::Lifecycle->DeleteLifecycle(
            CurrentUser => RT->SystemUser,
            Name        => $name,
        );
        ok( $del_ok, "Cleaned up lifecycle '$name'" ) or diag "Delete error: $del_msg";
        RT->Config->RefreshConfigFromDatabase();
        RT::Lifecycle->FillCache();
    }
}

diag "Test lifecycle functionality with special character names";

# Test that lifecycles with allowed special characters work correctly
{
    my @special_names = (
        'special-test',   # dash
        'special_test',   # underscore
        'special test',   # space
    );

    for my $name (@special_names) {
        my ( $ok, $msg ) = RT::Lifecycle->CreateLifecycle(
            CurrentUser => RT->SystemUser,
            Name        => $name,
            Type        => 'ticket',
            Clone       => 'default',
        );
        ok( $ok, "Created lifecycle '$name'" ) or diag "Error: $msg";

        RT->Config->RefreshConfigFromDatabase();
        RT::Lifecycle->FillCache();

        my $lifecycle = RT::Lifecycle->Load( Name => $name, Type => 'ticket' );
        ok( $lifecycle, "Loaded lifecycle '$name'" );
        is( $lifecycle->Name, $name, "Lifecycle name is correct for '$name'" );

        # Verify the lifecycle has valid statuses (cloned from default)
        # Default lifecycle has: new, open, stalled, resolved, rejected, deleted
        my @valid = $lifecycle->Valid;
        is( scalar @valid, 6, "Lifecycle '$name' has exactly 6 valid statuses" );
        is_deeply(
            [ sort @valid ],
            [ sort qw(new open stalled resolved rejected deleted) ],
            "Lifecycle '$name' has correct statuses cloned from default"
        );

        # Verify status type methods work
        ok( $lifecycle->IsInitial('new'), "Lifecycle '$name': 'new' is initial status" );
        ok( $lifecycle->IsActive('open'), "Lifecycle '$name': 'open' is active status" );
        ok( $lifecycle->IsInactive('resolved'), "Lifecycle '$name': 'resolved' is inactive status" );

        # Verify transitions work
        # Default lifecycle transitions from 'new': open, resolved, rejected, deleted
        my @transitions = $lifecycle->Transitions('new');
        is( scalar @transitions, 4, "Lifecycle '$name' has exactly 4 transitions from 'new'" );
        is_deeply(
            [ sort @transitions ],
            [ sort qw(open resolved rejected deleted) ],
            "Lifecycle '$name' transitions from 'new' match default lifecycle"
        );

        # Clean up
        RT->Config->RefreshConfigFromDatabase();
        RT::Lifecycle->FillCache();
        my ( $del_ok, $del_msg ) = RT::Lifecycle->DeleteLifecycle(
            CurrentUser => RT->SystemUser,
            Name        => $name,
        );
        ok( $del_ok, "Cleaned up lifecycle '$name'" ) or diag "Delete error: $del_msg";
    }
}

diag "Test empty name";
{
    my ( $ok, $msg ) = RT::Lifecycle->CreateLifecycle(
        CurrentUser => RT->SystemUser,
        Name        => '',
        Type        => 'ticket',
    );
    ok( !$ok, "Empty name rejected" );
    like( $msg, qr/Name required/, "Got correct error for empty name" );
}

done_testing;
