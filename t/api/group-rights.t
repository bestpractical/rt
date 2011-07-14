use strict;
use warnings;
use RT::Test nodata => 1, tests => 17;

RT::Group->AddRights(
    'RTxGroupRight' => 'Just a right for testing rights',
);

# this company is split into two halves, the hacks and the non-hacks
# herbert is a hacker but eric is not.
my $herbert = RT::User->new(RT->SystemUser);
my ($ok, $msg) = $herbert->Create(Name => 'herbert');
ok($ok, $msg);

my $eric = RT::User->new(RT->SystemUser);
($ok, $msg) = $eric->Create(Name => 'eric');
ok($ok, $msg);

my $hacks = RT::Group->new(RT->SystemUser);
($ok, $msg) = $hacks->CreateUserDefinedGroup(Name => 'Hackers');
ok($ok, $msg);

my $employees = RT::Group->new(RT->SystemUser);
($ok, $msg) = $employees->CreateUserDefinedGroup(Name => 'Employees');
ok($ok, $msg);

($ok, $msg) = $employees->AddMember($hacks->PrincipalId);
ok($ok, $msg);

($ok, $msg) = $hacks->AddMember($herbert->PrincipalId);
ok($ok, $msg);

($ok, $msg) = $employees->AddMember($eric->PrincipalId);
ok($ok, $msg);

ok($employees->HasMemberRecursively($hacks->PrincipalId), 'employees has member hacks');
ok($employees->HasMemberRecursively($herbert->PrincipalId), 'employees has member herbert');
ok($employees->HasMemberRecursively($eric->PrincipalId), 'employees has member eric');

ok($hacks->HasMemberRecursively($herbert->PrincipalId), 'hacks has member herbert');
ok(!$hacks->HasMemberRecursively($eric->PrincipalId), 'hacks does not have member eric');

{ # Eric doesn't have the right yet
    my $groups = RT::Groups->new(RT::CurrentUser->new($eric));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');

    is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], [], 'no joined groups have RTxGroupRight yet');
}

{ # Neither does Herbert
    my $groups = RT::Groups->new(RT::CurrentUser->new($herbert));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');
    is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], [], 'no joined groups have RTxGroupRight yet');
}

# Grant it to employees, on employees
($ok, $msg) = $employees->PrincipalObj->GrantRight(Right => 'RTxGroupRight', Object => $employees);
ok($ok, $msg);

{ # Eric is an Employee directly, so has it on Employees
    my $groups = RT::Groups->new(RT::CurrentUser->new($eric));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');
    is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], ['Employees']);
}

{ # Herbert is an Employee by way of Hackers, so should have it on both
    my $groups = RT::Groups->new(RT::CurrentUser->new($herbert));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');

    TODO: {
        local $TODO = "not recursing across groups within groups yet";
        is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], ['Employees', 'Hackers']);
    }
}
