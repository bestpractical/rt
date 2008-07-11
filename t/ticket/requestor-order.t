#!/usr/bin/perl -w
use strict; use warnings;

use RT::Test; use Test::More;
plan tests => 58;
use_ok('RT');


use RT::Model::Ticket;

my $q = RT::Model::Queue->new(current_user => RT->system_user);
my $queue = 'SearchTests-'.rand(200);
$q->create(name => $queue);

my @requestors = ( ('bravo@example.com') x 6, ('alpha@example.com') x 6,
                   ('delta@example.com') x 6, ('charlie@example.com') x 6,
                   (undef) x 6);
my @subjects = ("first test", "second test", "third test", "fourth test", "fifth test") x 6;
while (@requestors) {
    my $t = RT::Model::Ticket->new(current_user => RT->system_user);
    my ( $id, undef $msg ) = $t->create(
        queue      => $q->id,
        subject    => shift @subjects,
        requestor => [ shift @requestors ]
    );
    ok( $id, $msg );
}

{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue'");
    is($tix->count, 30, "found thirty tickets");
}

{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue' AND requestor = 'alpha\@example.com'");
    $tix->order_by({ column => "subject" });
    my @subjects;
    while (my $t = $tix->next) { push @subjects, $t->subject; }
    is(@subjects, 6, "found six tickets");
    is_deeply( \@subjects, [ sort @subjects ], "subjects are sorted");
}


sub check_emails_order
{
    my ($tix,$count,$order) = (@_);
    my @mails;
    while (my $t = $tix->next) { push @mails, $t->role_group("requestor")->member_emails_as_string; }
    is(@mails, $count, "found $count tickets for ". $tix->query);
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
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue' AND subject = 'first test' AND Requestor.email LIKE 'example.com'");
    $tix->order_by({ column => "requestor.email" });
    check_emails_order($tix, 5, 'ASC');
    $tix->order_by({ column => "requestor.email", order => 'DESC' });
    check_emails_order($tix, 5, 'DESC');
}

{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue' AND subject = 'first test'");
    $tix->order_by({ column => "requestor.email" });
    check_emails_order($tix, 6, 'ASC');
    $tix->order_by({ column => "requestor.email", order => 'DESC' });
    check_emails_order($tix, 6, 'DESC');
}


{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue' AND subject = 'first test'");
    $tix->order_by({ column => "requestor.email" });
    check_emails_order($tix, 6, 'ASC');
    $tix->order_by({ column => "requestor.email", order => 'DESC' });
    check_emails_order($tix, 6, 'DESC');
}

{
    # create ticket with group as member of the requestors group
    my $t = RT::Model::Ticket->new(current_user => RT->system_user);
    my ( $id, $msg ) = $t->create(
        queue      => $q->id,
        subject    => "first test",
        requestor  => 'badaboom@example.com',
    );
    ok( $id, "ticket Created" ) or diag( "error: $msg" );

    my $g = RT::Model::Group->new(current_user => RT->system_user);

    my ($gid);
    ($gid, $msg) = $g->create_user_defined_group(name => '20-sort-by-requestor.t-'.rand(200));
    ok($gid, "Created group") or diag("error: $msg");

    ($id, $msg) = $t->role_group("requestor")->add_member( $gid );
    ok($id, "added group to requestors group") or diag("error: $msg");
}

    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);    
    $tix->from_sql("Queue = '$queue' AND subject = 'first test'");

    $tix->order_by({ column => "requestor.email" });
    check_emails_order($tix, 7, 'ASC');

    $tix->order_by({ column => "requestor.email", order => 'DESC' });
    check_emails_order($tix, 7, 'DESC');

{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue'");
    $tix->order_by({ column => "requestor.email" });
    $tix->rows_per_page(30);
    my @mails;
    while (my $t = $tix->next) { push @mails, $t->role_group("requestor")->member_emails_as_string; }
    is(@mails, 30, "found thirty tickets");
    is_deeply( [grep {$_} @mails], [ sort grep {$_} @mails ], "Paging works (exclude nulls, which are db-dependant)");
}

{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '$queue'");
    $tix->order_by({ column => "requestor.email" });
    $tix->rows_per_page(30);
    my @mails;
    while (my $t = $tix->next) { push @mails, $t->role_group("requestor")->member_emails_as_string; }
    is(@mails, 30, "found thirty tickets");
    is_deeply( [grep {$_} @mails], [ sort grep {$_} @mails ], "Paging works (exclude nulls, which are db-dependant)");
}
RT::Test->mailsent_ok(25);

# vim:ft=perl:
