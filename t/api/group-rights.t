use strict;
use warnings;
use RT::Test nodata => 1, tests => 114;

RT::Group->AddRight( General =>
    'RTxGroupRight' => 'Just a right for testing rights',
);

# this company is split into two halves, the hackers and the non-hackers
# herbert is a hacker but eric is not.
my $herbert = RT::User->new(RT->SystemUser);
my ($ok, $msg) = $herbert->Create(Name => 'herbert');
ok($ok, $msg);

my $eric = RT::User->new(RT->SystemUser);
($ok, $msg) = $eric->Create(Name => 'eric');
ok($ok, $msg);

my $hackers = RT::Group->new(RT->SystemUser);
($ok, $msg) = $hackers->CreateUserDefinedGroup(Name => 'Hackers');
ok($ok, $msg);

my $employees = RT::Group->new(RT->SystemUser);
($ok, $msg) = $employees->CreateUserDefinedGroup(Name => 'Employees');
ok($ok, $msg);

($ok, $msg) = $employees->AddMember($hackers->PrincipalId);
ok($ok, $msg);

($ok, $msg) = $hackers->AddMember($herbert->PrincipalId);
ok($ok, $msg);

($ok, $msg) = $employees->AddMember($eric->PrincipalId);
ok($ok, $msg);

ok($employees->HasMemberRecursively($hackers->PrincipalId), 'employees has member hackers');
ok($employees->HasMemberRecursively($herbert->PrincipalId), 'employees has member herbert');
ok($employees->HasMemberRecursively($eric->PrincipalId), 'employees has member eric');

ok($hackers->HasMemberRecursively($herbert->PrincipalId), 'hackers has member herbert');
ok(!$hackers->HasMemberRecursively($eric->PrincipalId), 'hackers does not have member eric');

# There's also a separate group, "Other", which both are a member of.
my $other = RT::Group->new(RT->SystemUser);
($ok, $msg) = $other->CreateUserDefinedGroup(Name => 'Other');
ok($ok, $msg);
($ok, $msg) = $other->AddMember($eric->PrincipalId);
ok($ok, $msg);
($ok, $msg) = $other->AddMember($herbert->PrincipalId);
ok($ok, $msg);


# Everyone can SeeGroup on all three groups
my $everyone = RT::Group->new( RT->SystemUser );
($ok, $msg) = $everyone->LoadSystemInternalGroup( 'Everyone' );
ok($ok, $msg);
$everyone->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $employees);
$everyone->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $hackers);
$everyone->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $other);

sub CheckRights {
    my $cu = shift;
    my %groups = (Employees => 0, Hackers => 0, Other => 0, @_);
    my $name = $cu->Name;

    my $groups = RT::Groups->new(RT::CurrentUser->new($cu));
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(Right => 'RTxGroupRight');
    my %has_right = map { ($_->Name => 1) } @{ $groups->ItemsArrayRef };

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    for my $groupname (sort keys %groups) {
        my $g = RT::Group->new(RT::CurrentUser->new($cu));
        $g->LoadUserDefinedGroup($groupname);
        if ($groups{$groupname}) {
            ok( $g->CurrentUserHasRight("RTxGroupRight"), "$name has right on $groupname (direct query)" );
            ok( delete $has_right{$groupname},            "..and also in ForWhichCurrentUserHasRight");
        } else {
            ok( !$g->CurrentUserHasRight("RTxGroupRight"), "$name doesn't have right on $groupname (direct query)" );
            ok( !delete $has_right{$groupname},            "..and also not in ForWhichCurrentUserHasRight");
        }
    }
    ok(not(keys %has_right), "ForWhichCurrentUserHasRight has no extra groups");
}

# Neither should have it on any group yet
CheckRights($eric);
CheckRights($herbert);


# Grant it to employees, on employees.  Both Herbert and Eric will have
# it on employees, though Herbert gets it by way of hackers.  Neither
# will have it on hackers, because the target does not recurse.
$employees->PrincipalObj->GrantRight( Right => 'RTxGroupRight', Object => $employees);
CheckRights($eric,    Employees => 1);
CheckRights($herbert, Employees => 1);


# Grant it to employees, on hackers.  This means both Eric and Herbert
# will have the right on hackers, but not on employees.
$employees->PrincipalObj->RevokeRight(Right => 'RTxGroupRight', Object => $employees);
$employees->PrincipalObj->GrantRight( Right => 'RTxGroupRight', Object => $hackers);
CheckRights($eric,    Hackers => 1);
CheckRights($herbert, Hackers => 1);


# Grant it to hackers, on employees.  Eric will have it nowhere, and
# Herbert will have it on employees.  Note that the target of the right
# itself does _not_ recurse down, so Herbert will not have it on
# hackers.
$employees->PrincipalObj->RevokeRight(Right => 'RTxGroupRight', Object => $hackers);
$hackers->PrincipalObj->GrantRight(   Right => 'RTxGroupRight', Object => $employees);
CheckRights($eric);
CheckRights($herbert, Employees => 1);


# Grant it globally to hackers; herbert will see the right on all
# employees, hackers, and other.
$hackers->PrincipalObj->RevokeRight(  Right => 'RTxGroupRight', Object => $employees);
$hackers->PrincipalObj->GrantRight(   Right => 'RTxGroupRight', Object => RT->System);
CheckRights($eric);
CheckRights($herbert, Employees => 1, Hackers => 1, Other => 1 );


# Grant it globally to employees; both eric and herbert will see the
# right on all employees, hackers, and other.
$hackers->PrincipalObj->RevokeRight(  Right => 'RTxGroupRight', Object => RT->System);
$employees->PrincipalObj->GrantRight( Right => 'RTxGroupRight', Object => RT->System);
CheckRights($eric,    Employees => 1, Hackers => 1, Other => 1 );
CheckRights($herbert, Employees => 1, Hackers => 1, Other => 1 );


# Disable the employees group.  Neither eric nor herbert will see the
# right anywhere.
$employees->SetDisabled(1);
CheckRights($eric);
CheckRights($herbert);
