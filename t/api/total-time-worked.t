use strict;
use warnings;
use RT;
use RT::Test tests => undef;

my $scrip = RT::Scrip->new(RT->SystemUser);
$scrip->LoadByCols(Description => 'On TimeWorked Change Update Parent TimeWorked');
$scrip->SetDisabled(1);


diag("Test tickets total time worked");
{
    my $parent = RT::Ticket->new(RT->SystemUser);
    my ($ok1,$msg1) = $parent->Create(
        Queue => 'general',
        Subject => 'total time worked test parent',
    );
    ok($ok1,"Created parent ticket $msg1");

    my $child = RT::Ticket->new(RT->SystemUser);
    my ($ok2,$msg2) = $child->Create(
        Queue => 'general',
        Subject => 'total time worked test child',
    );
    ok($ok2,"Created child ticket $msg2");

    my $grandchild = RT::Ticket->new(RT->SystemUser);
    my ($ok3,$msg3) = $grandchild->Create(
        Queue => 'general',
        Subject => 'total time worked test child child',
    );
    ok($ok3,"Created grandchild ticket $msg3");

    my ($ok4,$msg4) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $child->id,
    );
    ok($ok4,"Created parent -> child link $msg4");

    my ($ok5,$msg5) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok($ok5,"Created child -> grandchild link $msg5");

    my $grandchild2 = RT::Ticket->new(RT->SystemUser);
    my ($ok6,$msg6) = $grandchild2->Create(
        Queue => 'general',
        Subject => 'total time worked test other child child',
    );
    ok($ok6,"Create second grandchild $msg6");

    my ($ok7,$msg7) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild2->id,
    );
    ok($ok7,"Create child -> second grandchild link $msg7");

    $parent->SetTimeWorked(10);
    $child->SetTimeWorked(20);
    $grandchild->SetTimeWorked(40);
    $grandchild2->SetTimeWorked(50);

    is $grandchild2->TimeWorked, 50, 'check other child child time worked';
    is $grandchild->TimeWorked, 40, 'check child child time worked';
    is $child->TimeWorked, 20, 'check child time worked';
    is $parent->TimeWorked, 10, 'check parent time worked';

    is $parent->TotalTimeWorked, 120, 'check parent total time worked';
    is $child->TotalTimeWorked, 110, 'check child total time worked';
    is $grandchild->TotalTimeWorked, 40, 'check child child total time worked';
    is $grandchild2->TotalTimeWorked, 50, 'check other child child total time worked';

    is $parent->TotalTimeWorkedAsString, '2 hours (120 minutes)', 'check parent total time worked as string';
    is $grandchild->TotalTimeWorkedAsString, '40 minutes', 'check child child total time workd as string';
}

diag("Test multiple inheritance total time worked");
{
    my $parent = RT::Ticket->new(RT->SystemUser);
    my ($ok1,$msg1) = $parent->Create(
        Queue => 'general',
        Subject => 'total time worked test parent',
    );
    ok $ok1, "created parent ticket $msg1";

    my $child = RT::Ticket->new(RT->SystemUser);
    my ($ok2,$msg2) = $child->Create(
        Queue => 'general',
        Subject => 'total time worked test child',
    );
    ok $ok2, "created child ticket $msg2";

    my $grandchild = RT::Ticket->new(RT->SystemUser);
    my ($ok3,$msg3) = $grandchild->Create(
        Queue => 'general',
        Subject => 'total time worked test child child, and test child',
    );
    ok $ok3, "created grandchild ticket $msg3";

    $parent->SetTimeWorked(10);
    $child->SetTimeWorked(20);
    $grandchild->SetTimeWorked(40);

    my ($ok4,$msg4) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $child->id,
    );
    ok $ok4, "Create parent -> child link $msg4";

    my ($ok5,$msg5) = $child->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok $ok5, "Create child -> grandchild link $msg5";

     my ($ok6,$msg6) = $parent->AddLink(
        Type => 'MemberOf',
        Base => $grandchild->id,
    );
    ok $ok6, "Created parent -> grandchild link $msg6";

    is $parent->TotalTimeWorked, 70, 'check parent total time worked';
    is $child->TotalTimeWorked, 60, 'check child total time worked';
    is $grandchild->TotalTimeWorked, 40, 'check child child total time worked';

}

diag("Test inheritance total time worked");
{
    my @warnings;

    my $parent = RT::Ticket->new(RT->SystemUser);
    my ($ok1,$msg1) = $parent->Create(
        Queue => 'general',
        Subject => 'total time worked test parent',
    );
    ok $ok1, "created parent ticket $msg1";

    my $child = RT::Ticket->new(RT->SystemUser);
    my ($ok2,$msg2) = $child->Create(
        Queue => 'general',
        Subject => 'total time worked test child',
    );
    ok $ok2, "created child ticket $msg2";

    {
        local $SIG{__WARN__} = sub {
            push @warnings, @_;
        };

        my ($ok3,$msg3) = $parent->AddLink(
            Type => 'MemberOf',
            Base => $child->id,
        );
        ok $ok3, "Created parent -> child link $msg3";
        my ($ok4,$msg4) = $parent->AddLink(
            Type => 'MemberOf',
            Base => 'http://bestpractical.com',
        );
        ok $ok4, "Create parent -> url link $msg4";

        my ($ok5,$msg5) = $child->AddLink(
            Type => 'MemberOf',
            Base => 'http://docs.bestpractical.com/',
        );
        ok $ok5, "Created child -> url link $msg5";

    }

    $parent->SetTimeWorked(10);
    $child->SetTimeWorked(20);

    is $parent->TotalTimeWorked, 30, 'check parent total time worked';
    is $child->TotalTimeWorked, 20, 'check child total time worked';

   TODO: {
       local $TODO = "this warns because of the unrelated I#31399";
       is(@warnings, 0, "no warnings");
   }
}

done_testing;
