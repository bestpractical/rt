use strict;
use warnings;
use RT;
use RT::Test tests => undef;

diag( "Test tickets total time left" );
{
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ( $ok, $msg ) = $parent->Create(
        Queue   => 'general',
        Subject => 'total time left test parent',
    );
    ok( $ok, "Created parent ticket $msg" );

    my $child = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $child->Create(
        Queue   => 'general',
        Subject => 'total time left test child',
    );
    ok( $ok, "Created child ticket $msg" );

    my $grandchild = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $grandchild->Create(
        Queue   => 'general',
        Subject => 'total time left test child child',
    );
    ok( $ok, "Created grandchild ticket $msg" );

    ( $ok, $msg ) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $child->id,
    );
    ok( $ok, "Created parent -> child link $msg" );

    ( $ok, $msg ) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok( $ok, "Created child -> grandchild link $msg" );

    my $grandchild2 = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $grandchild2->Create(
        Queue   => 'general',
        Subject => 'total time left test other child child',
    );
    ok( $ok, "Create second grandchild $msg" );

    ( $ok, $msg ) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild2->id,
    );
    ok( $ok, "Create child -> second grandchild link $msg" );

    $parent->SetTimeLeft( 10 );
    $child->SetTimeLeft( 20 );
    $grandchild->SetTimeLeft( 40 );
    $grandchild2->SetTimeLeft( 50 );

    is $grandchild2->TimeLeft, 50, 'check other child child time left';
    is $grandchild->TimeLeft,  40, 'check child child time left';
    is $child->TimeLeft,       20, 'check child time left';
    is $parent->TimeLeft,      10, 'check parent time left';

    is $parent->TotalTimeLeft,      120, 'check parent total time left';
    is $child->TotalTimeLeft,       110, 'check child total time left';
    is $grandchild->TotalTimeLeft,  40,  'check child child total time left';
    is $grandchild2->TotalTimeLeft, 50,  'check other child child total time left';

    is $parent->TotalTimeLeftAsString,     '2 hours (120 minutes)', 'check parent total time left as string';
    is $grandchild->TotalTimeLeftAsString, '40 minutes',            'check child child total time workd as string';
}

diag( "Test multiple inheritance total time left" );
{
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ( $ok, $msg ) = $parent->Create(
        Queue   => 'general',
        Subject => 'total time left test parent',
    );
    ok $ok, "created parent ticket $msg";

    my $child = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $child->Create(
        Queue   => 'general',
        Subject => 'total time left test child',
    );
    ok $ok, "created child ticket $msg";

    my $grandchild = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $grandchild->Create(
        Queue   => 'general',
        Subject => 'total time left test child child, and test child',
    );
    ok $ok, "created grandchild ticket $msg";

    $parent->SetTimeLeft( 10 );
    $child->SetTimeLeft( 20 );
    $grandchild->SetTimeLeft( 40 );

    ( $ok, $msg ) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $child->id,
    );
    ok $ok, "Create parent -> child link $msg";

    ( $ok, $msg ) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok $ok, "Create child -> grandchild link $msg";

    ( $ok, $msg ) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok $ok, "Created parent -> grandchild link $msg";

    is $parent->TotalTimeLeft,     70, 'check parent total time left';
    is $child->TotalTimeLeft,      60, 'check child total time left';
    is $grandchild->TotalTimeLeft, 40, 'check child child total time left';

}

diag( "Test inheritance total time left" );
{
    my @warnings;

    my $parent = RT::Ticket->new( RT->SystemUser );
    my ( $ok, $msg ) = $parent->Create(
        Queue   => 'general',
        Subject => 'total time left test parent',
    );
    ok $ok, "created parent ticket $msg";

    my $child = RT::Ticket->new( RT->SystemUser );
    ( $ok, $msg ) = $child->Create(
        Queue   => 'general',
        Subject => 'total time left test child',
    );
    ok $ok, "created child ticket $msg";

    {
        local $SIG{__WARN__} = sub {
            push @warnings, @_;
        };

        my ( $ok, $msg ) = $parent->AddLink(
            Type => 'MemberOf',
            Base => $child->id,
        );
        ok $ok, "Created parent -> child link $msg";
        ( $ok, $msg ) = $parent->AddLink(
            Type => 'MemberOf',
            Base => 'http://bestpractical.com',
        );
        ok $ok, "Create parent -> url link $msg";

        ( $ok, $msg ) = $child->AddLink(
            Type => 'MemberOf',
            Base => 'http://docs.bestpractical.com/',
        );
        ok $ok, "Created child -> url link $msg";

    }

    $parent->SetTimeLeft( 10 );
    $child->SetTimeLeft( 20 );

    is $parent->TotalTimeLeft, 30, 'check parent total time left';
    is $child->TotalTimeLeft,  20, 'check child total time left';

  TODO: {
        local $TODO = "this warns because of the unrelated I#31399";
        is( @warnings, 0, "no warnings" );
    }
}

done_testing;
