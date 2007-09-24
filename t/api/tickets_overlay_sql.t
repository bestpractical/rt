
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use RT::Model::TicketCollection;
use strict;

my $tix = RT::Model::TicketCollection->new(RT->SystemUser);
{
    my $query = "Status = 'open'";
    my ($status, $msg)  = $tix->from_sql($query);
    ok ($status, "correct query") or diag("error: $msg");
}


my (@Created,%Created);
my $string = 'subject/content SQL test';
{
    my $t = RT::Model::Ticket->new(RT->SystemUser);
    ok( $t->create(Queue => 'General', Subject => $string), "Ticket Created");
    $Created{ $t->id }++; push @Created, $t->id;
}

{
    my $Message = MIME::Entity->build(
                     Subject     => 'this is my subject',
                     From        => 'jesse@example.com',
                     Data        => [ $string ],
            );

    my $t = RT::Model::Ticket->new(RT->SystemUser);
    ok( $t->create( Queue => 'General',
                    Subject => 'another ticket',
                    MIMEObj => $Message,
                    MemberOf => $Created[0]
                  ),
        "Ticket Created"
    );
    $Created{ $t->id }++; push @Created, $t->id;
}

{
    my $query = ("Subject LIKE '$string' OR Content LIKE '$string'");
    my ($status, $msg) = $tix->from_sql($query);
    ok ($status, "correct query") or diag("error: $msg");

    my $count = 0;
    while (my $tick = $tix->next) {
        $count++ if $Created{ $tick->id };
    }
    is ($count, scalar @Created, "number of returned tickets same as entered");
}

{
    my $query = "id = $Created[0] OR MemberOf = $Created[0]";
    my ($status, $msg) = $tix->from_sql($query);
    ok ($status, "correct query") or diag("error: $msg");

    my $count = 0;
    while (my $tick = $tix->next) {
        $count++ if $Created{ $tick->id };
    }
    is ($count, scalar @Created, "number of returned tickets same as entered");
}



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
