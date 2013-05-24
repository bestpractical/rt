use strict;
use warnings;

use RT::Test tests => undef;
use Set::Tiny;

my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, "@_";
};

my $requestor = RT::Group->new( RT->SystemUser );
$requestor->LoadRoleGroup(
    Object  => RT->System,
    Name    => "Requestor",
);
ok $requestor->id, "Loaded global requestor role group";

$requestor = $requestor->PrincipalObj;
ok $requestor->id, "Loaded global requestor role group principal";

note "Try granting an article right to a system role group";
{
    my ($ok, $msg) = $requestor->GrantRight(
        Right   => "ShowArticle",
        Object  => RT->System,
    );
    ok !$ok, "Couldn't grant nonsensical right to global Requestor role: $msg";
    like shift @warnings, qr/Couldn't validate right name.*?ShowArticle/;

    ($ok, $msg) = $requestor->GrantRight(
        Right   => "ShowTicket",
        Object  => RT->System,
    );
    ok $ok, "Granted queue right to global queue role: $msg";

    ($ok, $msg) = RT->PrivilegedUsers->PrincipalObj->GrantRight(
        Right   => "ShowArticle",
        Object  => RT->System,
    );
    ok $ok, "Granted article right to non-role global group: $msg";

    reset_rights();
}

note "AvailableRights";
{
    my @available = (
        [ keys %{RT->System->AvailableRights} ],
        [ keys %{RT->System->AvailableRights( $requestor )} ],
    );

    my $all  = Set::Tiny->new( @{$available[0]} );
    my $role = Set::Tiny->new( @{$available[1]} );

    ok $role->is_proper_subset($all), "role rights are a proper subset of all";
}

ok !@warnings, "No uncaught warnings"
    or diag explain \@warnings;

# for clarity
sub reset_rights { RT::Test->set_rights() }

done_testing;
