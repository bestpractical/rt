
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



{

use RT::Model::TicketCollection;
use strict;

my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
{
    my $query = "Status = 'open'";
    my ($status, $msg)  = $tix->from_sql($query);
    ok ($status, "correct query") or diag("error: $msg");
}


my (@Created,%Created);
my $string = 'subject/content SQL test';
{
    my $t = RT::Model::Ticket->new(current_user => RT->system_user);
    ok( $t->create(queue => 'General', subject => $string), "Ticket Created");
    $Created{ $t->id }++; push @Created, $t->id;
}

{
    my $Message = MIME::Entity->build(
                     subject     => 'this is my subject',
                     From        => 'jesse@example.com',
                     Data        => [ $string ],
            );

    my $t = RT::Model::Ticket->new(current_user => RT->system_user);
    ok( $t->create( queue => 'General',
                    subject => 'another ticket',
                    mime_obj => $Message,
                    MemberOf => $Created[0]
                  ),
        "Ticket Created"
    );
    $Created{ $t->id }++; push @Created, $t->id;
}

{
    my $query = ("subject LIKE '$string' OR content LIKE '$string'");
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



}

1;
