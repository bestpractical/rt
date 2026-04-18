use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;

my $group = RT::Test->load_or_create_group( 'WebPolicyGroup' );
my $group_id = $group->Id;

$m->login( 'root', 'password' );

diag 'Password Policy tab appears for user-defined group';
{
    $m->get_ok( $baseurl . '/Admin/Groups/Modify.html?id=' . $group_id );
    $m->content_contains( 'Password Policy', 'Password Policy tab present' );
}

diag 'Password Policy page loads';
{
    $m->get_ok( $baseurl . '/Admin/Groups/PasswordPolicy.html?id=' . $group_id );
    $m->content_contains( 'Minimum password length', 'MinLength field present' );
    $m->content_contains( 'RequireUpper',            'RequireUpper field present' );
    $m->content_contains( 'RequireLower',            'RequireLower field present' );
    $m->content_contains( 'RequireDigit',            'RequireDigit field present' );
    $m->content_contains( 'RequireSymbol',           'RequireSymbol field present' );
    $m->content_contains( 'NoUsername',              'NoUsername field present' );
}

diag 'Admin can set a group password policy';
{
    $m->post_ok(
        $baseurl . '/Admin/Groups/PasswordPolicy.html',
        {   id                   => $group_id,
            MinLength            => 10,
            RequireUpper         => 1,
            RequireDigit         => 1,
            UpdatePasswordPolicy => 1,
        }
    );
    $m->content_contains( 'Password policy updated', 'Success message shown' );

    # Verify stored
    $group->ClearAttributes;
    my $policy = $group->PasswordPolicy;
    is( $policy->{MinLength},    10, 'MinLength saved' );
    is( $policy->{RequireUpper}, 1,  'RequireUpper saved' );
    is( $policy->{RequireDigit}, 1,  'RequireDigit saved' );
}

diag 'Admin can clear a group password policy';
{
    $m->post_ok(
        $baseurl . '/Admin/Groups/PasswordPolicy.html',
        {   id    => $group_id,
            Reset => 1,
        }
    );
    $m->content_contains( 'Password policy reset', 'Reset message shown' );

    $group->ClearAttributes;
    is( $group->PasswordPolicy, undef, 'Policy attribute removed' );
}

diag 'Policy requirements shown on Admin/Users/Modify.html';
{
    # Set a policy on WebPolicyGroup
    $group->SetPasswordPolicy( MinLength => 10, RequireUpper => 1 );

    my $user = RT::Test->load_or_create_user(
        Name         => 'policy_display_user',
        EmailAddress => 'pdisplay@example.com',
        Password     => 'Password1abc',
    );
    ok( $user->Id, 'Created test user' );
    $group->AddMember( $user->PrincipalId );

    $m->get_ok( $baseurl . '/Admin/Users/Modify.html?id=' . $user->Id );
    $m->content_contains( 'At least 10', 'Min length 10 shown near password field' );
    $m->content_contains( 'uppercase',   'Uppercase requirement shown near password field' );
}

diag 'Policy violations rejected with correct error on Admin/Users/Modify.html';
{
    my $user = RT::User->new( RT->SystemUser );
    $user->Load('policy_display_user');

    $m->post_ok(
        $baseurl . '/Admin/Users/Modify.html',
        {   id    => $user->Id,
            Pass1 => 'alllowercase1',
            Pass2 => 'alllowercase1',
        }
    );
    $m->content_contains( 'uppercase', 'Validation error shown for missing uppercase' );
}

diag 'Valid password accepted';
{
    my $user = RT::User->new( RT->SystemUser );
    $user->Load('policy_display_user');

    $m->post_ok(
        $baseurl . '/Admin/Users/Modify.html',
        {   id    => $user->Id,
            Pass1 => 'ValidPass1abc',
            Pass2 => 'ValidPass1abc',
        }
    );
    $m->content_lacks( 'at least one uppercase', 'No uppercase error for valid password' );
}

done_testing;
