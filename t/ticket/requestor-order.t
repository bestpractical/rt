use strict;
use warnings;

use RT::Test tests => 58;
use_ok('RT');

use RT::Ticket;

my $q = RT::Queue->new(RT->SystemUser);
my $queue = 'SearchTests-'.rand(200);
$q->Create(Name => $queue);

my @requestors = ( ('bravo@example.com') x 6, ('alpha@example.com') x 6,
                   ('delta@example.com') x 6, ('charlie@example.com') x 6,
                   (undef) x 6);
my @subjects = ("first test", "second test", "third test", "fourth test", "fifth test") x 6;
while (@requestors) {
    my $t = RT::Ticket->new(RT->SystemUser);
    my ( $id, undef, $msg ) = $t->Create(
        Queue      => $q->id,
        Subject    => shift @subjects,
        Requestor => [ shift @requestors ]
    );
    ok( $id, $msg );
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, 30, "found thirty tickets");
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND requestor = 'alpha\@example.com'");
    $tix->OrderByCols({ FIELD => "Subject" });
    my @subjects;
    while (my $t = $tix->Next) { push @subjects, $t->Subject; }
    is(@subjects, 6, "found six tickets");
    is_deeply( \@subjects, [ sort @subjects ], "Subjects are sorted");
}

sub check_emails_order
{
    my ($tix,$count,$order) = (@_);
    my @mails;
    while (my $t = $tix->Next) { push @mails, $t->RequestorAddresses; }
    is(@mails, $count, "found $count tickets for ". $tix->Query);
    my @required_order;
    if( $order =~ /asc/i ) {
        @required_order = sort { $a? ($b? ($a cmp $b) : -1) : 1} @mails;
    } else {
        @required_order = sort { $a? ($b? ($b cmp $a) : -1) : 1} @mails;
    }
    foreach( reverse splice @mails ) {
        if( $_ ) { unshift @mails, $_ }
        else { push @mails, $_ }
    }
    is_deeply( \@mails, \@required_order, "Addresses are sorted");
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND subject = 'first test' AND Requestor.EmailAddress LIKE 'example.com'");
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    check_emails_order($tix, 5, 'ASC');
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress", ORDER => 'DESC' });
    check_emails_order($tix, 5, 'DESC');
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Subject = 'first test'");
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    check_emails_order($tix, 6, 'ASC');
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress", ORDER => 'DESC' });
    check_emails_order($tix, 6, 'DESC');
}


{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Subject = 'first test'");
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    check_emails_order($tix, 6, 'ASC');
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress", ORDER => 'DESC' });
    check_emails_order($tix, 6, 'DESC');
}

{
    # create ticket with group as member of the requestors group
    my $t = RT::Ticket->new(RT->SystemUser);
    my ( $id, $msg ) = $t->Create(
        Queue      => $q->id,
        Subject    => "first test",
        Requestor  => 'badaboom@example.com',
    );
    ok( $id, "ticket created" ) or diag( "error: $msg" );

    my $g = RT::Group->new(RT->SystemUser);

    my ($gid);
    ($gid, $msg) = $g->CreateUserDefinedGroup(Name => '20-sort-by-requestor.t-'.rand(200));
    ok($gid, "created group") or diag("error: $msg");

    ($id, $msg) = $t->Requestors->AddMember( $gid );
    ok($id, "added group to requestors group") or diag("error: $msg");
}

    my $tix = RT::Tickets->new(RT->SystemUser);    
    $tix->FromSQL("Queue = '$queue' AND Subject = 'first test'");

    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    check_emails_order($tix, 7, 'ASC');

    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress", ORDER => 'DESC' });
    check_emails_order($tix, 7, 'DESC');

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    $tix->RowsPerPage(30);
    my @mails;
    while (my $t = $tix->Next) { push @mails, $t->RequestorAddresses; }
    is(@mails, 30, "found thirty tickets");
    is_deeply( [grep {$_} @mails], [ sort grep {$_} @mails ], "Paging works (exclude nulls, which are db-dependant)");
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    $tix->OrderByCols({ FIELD => "Requestor.EmailAddress" });
    $tix->RowsPerPage(30);
    my @mails;
    while (my $t = $tix->Next) { push @mails, $t->RequestorAddresses; }
    is(@mails, 30, "found thirty tickets");
    is_deeply( [grep {$_} @mails], [ sort grep {$_} @mails ], "Paging works (exclude nulls, which are db-dependant)");
}
RT::Test->mailsent_ok(25);
