use strict;
use warnings;
use RT::Test nodata => 1, no_plan => 1;

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

# There's also a separate group, "Other", which both are a member of.
my $other = RT::Group->new(RT->SystemUser);
($ok, $msg) = $other->CreateUserDefinedGroup(Name => 'Other');
ok($ok, $msg);
($ok, $msg) = $other->AddMember($eric->PrincipalId);
ok($ok, $msg);
($ok, $msg) = $other->AddMember($herbert->PrincipalId);
ok($ok, $msg);


{ # Eric doesn't have the right yet
    my $g = RT::Group->new(RT::CurrentUser->new($eric));
    $g->Load($employees->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Eric doesn't yet have the right on employees");
    $g->Load($hacks->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Nor on hackers");
    $g->Load($other->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Nor on other");

    my $groups = RT::Groups->new(RT::CurrentUser->new($eric));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');

    is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], [], 'no joined groups have RTxGroupRight yet');
}

{ # Neither does Herbert
    my $g = RT::Group->new(RT::CurrentUser->new($herbert));
    $g->Load($employees->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Herbert doesn't yet have the right on employees");
    $g->Load($hacks->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Nor on hackers");
    $g->Load($other->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Nor on other");

    my $groups = RT::Groups->new(RT::CurrentUser->new($herbert));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');
    is_deeply([sort map { $_->Name } @{ $groups->ItemsArrayRef }], [], 'no joined groups have RTxGroupRight yet');
}

# Grant it to employees, on employees
($ok, $msg) = $employees->PrincipalObj->GrantRight(Right => 'RTxGroupRight', Object => $employees);
ok($ok, $msg);

{ # Eric is an Employee directly, so has it on Employees, but not on Hack or Other
    my $g = RT::Group->new(RT::CurrentUser->new($eric));
    $g->Load($employees->Id);
    ok($g->CurrentUserHasRight("RTxGroupRight"), "Eric has the right on employees");
    $g->Load($hacks->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Doesn't have it on hackers");
    $g->Load($other->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Nor on other");

    my $groups = RT::Groups->new(RT::CurrentUser->new($eric));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');
    my %has_right = map { ($_->Name => 1) } @{ $groups->ItemsArrayRef };
    ok(delete $has_right{Employees}, "Has the right on a group it's in");
    ok(not(delete $has_right{Hackers}), "Doesn't have the right on a group it's not in");
    ok(not(delete $has_right{Other}), "Doesn't have the right on a group it's in");
    ok(not(keys %has_right), "Has no other groups")
}

{ # Herbert is an Employee by way of Hackers, so should have it on both
    my $g = RT::Group->new(RT::CurrentUser->new($herbert));
    $g->Load($employees->Id);
    ok($g->CurrentUserHasRight("RTxGroupRight"), "Herbert has the right on employees");
    $g->Load($hacks->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "Also has it on hackers");
    $g->Load($other->Id);
    ok(!$g->CurrentUserHasRight("RTxGroupRight"), "But not on other");

    my $groups = RT::Groups->new(RT::CurrentUser->new($herbert));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');

    my %has_right = map { ($_->Name => 1) } @{ $groups->ItemsArrayRef };
    ok(delete $has_right{Employees}, "Has the right on a group it's in");
    ok(delete $has_right{Hackers}, "Grants the right recursively");
    ok(not(delete $has_right{Other}), "Doesn't have the right on a group it's in");
    ok(not(keys %has_right), "Has no other groups")
}
