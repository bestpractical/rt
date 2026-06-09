use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

# Regression test for negative TicketSQL searches on a *role subfield* (e.g.
# 'CustomRole.{Reviewer}.Organization' != 'X').
#
# RT::SearchBuilder::Role::Roles::RoleLimit handles a negated role-subfield
# search by first counting how many users match the value. When more than one
# user matches it takes a separate ("semi-working") code path that builds a
# per-row anti-join: LEFT JOIN Users ... ON (member = user AND user.col = val)
# then WHERE Users.id IS NULL. For a multi-valued role, that IS NULL is
# satisfied by *any* member who does not match -- so a ticket whose role has
# one matching member and one non-matching member leaks through.
#
# The correct semantics (already produced by the single-user branch) is to
# exclude a ticket when ANY member of the role matches the value.

my $queue = RT::Test->load_or_create_queue( Name => 'RoleOrg' );
ok $queue && $queue->id, 'loaded or created queue';
my $qname = $queue->Name;

# Two users share the 'Engineering' organization -- this is what forces the
# ">1 matching users" branch. A single user in 'Sales' exercises the
# single-user branch as a control.
my $alice = RT::Test->load_or_create_user( EmailAddress => 'alice@example.com' );
my $amy   = RT::Test->load_or_create_user( EmailAddress => 'amy@example.com' );
my $bob   = RT::Test->load_or_create_user( EmailAddress => 'bob@example.com' );

for my $u ( $alice, $amy ) {
    my ( $ok, $msg ) = $u->SetOrganization('Engineering');
    ok( $ok, 'set Engineering org on ' . $u->EmailAddress . ": $msg" );
}
{
    my ( $ok, $msg ) = $bob->SetOrganization('Sales');
    ok( $ok, "set Sales org on bob: $msg" );
}

# Multi-valued custom role (MaxValues => 0) applied to the queue.
my $reviewer = RT::CustomRole->new( RT->SystemUser );
my ( $ok, $msg ) = $reviewer->Create( Name => 'Reviewer-' . $$, MaxValues => 0 );
ok( $ok, "created Reviewer role: $msg" );
( $ok, $msg ) = $reviewer->AddToObject( $queue->id );
ok( $ok, "applied Reviewer role to queue: $msg" );
my $role  = $reviewer->GroupType;
my $rname = $reviewer->Name;

my $t_eng = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 't_eng',
    $role   => [ $alice->EmailAddress ],
);
my $t_sales = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 't_sales',
    $role   => [ $bob->EmailAddress ],
);
my $t_mixed = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 't_mixed',
    $role   => [ $alice->EmailAddress, $bob->EmailAddress ],
);
my $t_none = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 't_none',
);

# sanity: t_mixed really has both reviewers
is( $t_mixed->RoleAddresses($role),
    ( join ', ', sort $alice->EmailAddress, $bob->EmailAddress ),
    't_mixed has both an Engineering and a Sales reviewer' );

sub search_subjects {
    my $query = shift;
    my $tix   = RT::Tickets->new( RT->SystemUser );
    $tix->FromSQL($query);
    return [ sort map { $_->Subject } @{ $tix->ItemsArrayRef } ];
}

diag 'negative search on role Organization, value matched by >1 users';
{
    # 'Engineering' is shared by alice + amy -> ">1 users" branch.
    # Exclude every ticket with ANY reviewer in Engineering (t_eng, t_mixed).
    # Tickets with no matching reviewer -- including t_none, which has no
    # reviewer at all -- are returned (consistent with the single-user branch).
    my $q = "Queue = '$qname' AND 'CustomRole.{$rname}.Organization' != 'Engineering'";
    is_deeply( search_subjects($q), [ 't_none', 't_sales' ],
        "!= Organization excludes t_mixed despite its non-Engineering reviewer" );

    my $q2 = "Queue = '$qname' AND 'CustomRole.{$rname}.Organization' NOT LIKE 'Engineering'";
    is_deeply( search_subjects($q2), [ 't_none', 't_sales' ],
        "NOT LIKE Organization excludes t_mixed too" );
}

diag 'control: negative search on role Organization, value matched by 1 user';
{
    # 'Sales' belongs only to bob -> single-user branch (already correct).
    my $q = "Queue = '$qname' AND 'CustomRole.{$rname}.Organization' != 'Sales'";
    is_deeply( search_subjects($q), [ 't_eng', 't_none' ],
        "!= Sales excludes t_sales and t_mixed" );
}

diag 'control: positive search is unaffected';
{
    my $q = "Queue = '$qname' AND 'CustomRole.{$rname}.Organization' = 'Engineering'";
    is_deeply( search_subjects($q), [ 't_eng', 't_mixed' ],
        "= Engineering matches both tickets with an Engineering reviewer" );
}

done_testing;
