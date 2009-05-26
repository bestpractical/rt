use strict;
use warnings;
use RT::Test tests => 11;

for (1 .. 10) {
    my $t = RT::Model::Ticket->new(current_user => RT->system_user);
    my ($ok, $msg) = $t->create(
        queue   => 'General',
        subject => "Test ticket $_",
    );
    ok($ok, "Created ticket $_");
}

my $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->limit_status(value => 'new');
$tickets->set_page_info(per_page => 5);

my $count = 0;
while (my $ticket = $tickets->next) {
    ++$count;
}

TODO: {
    local $TODO = "Doesn't work yet!";
    is($count, 5, "set_page_info");
}

