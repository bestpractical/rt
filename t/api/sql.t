use strict;
use warnings;

use RT::Test tests => undef;

# The IN version of this SQL is 4x faster in a real RT instance.
my $users = RT::Users->new( RT->SystemUser );
$users->WhoHaveGroupRight( Right => 'OwnTicket', Object => RT->System, IncludeSuperusers => 1 );
like(
    $users->BuildSelectQuery,
    qr{RightName IN \('SuperUser', 'OwnTicket'\)},
    'RightName check in WhoHaveGroupRight uses IN'
);

my $root_id  = RT::Test->load_or_create_user( Name => 'root' )->id;
my $alice_id = RT::Test->load_or_create_user( Name => 'alice' )->id;
my $general_id = RT::Test->load_or_create_queue( Name => 'General' )->id;
my $support_id = RT::Test->load_or_create_queue( Name => 'Support' )->id;

my %ticketsql = (
    q{Status = 'new' OR Status = 'open'}                => qr{Status IN \('new', 'open'\)},
    q{Status = '__Active__'}                            => qr{Status IN \('new', 'open', 'stalled'\)},
    q{id = 2 OR id = 3}                                 => qr{id IN \('2', '3'\)},
    q{Creator = 'root' OR Creator = 'alice'}            => qr{Creator IN \('$alice_id', '$root_id'\)},
    q{Queue = 'General' OR Queue = 'Support'}           => qr{Queue IN \('$general_id', '$support_id'\)},
    q{Lifecycle = 'default' or Lifecycle = 'approvals'} => qr{Lifecycle IN \('approvals', 'default'\)},
    q{(Queue = 'General' OR Queue = 'Support') AND (Status = 'new' OR Status = 'open')} =>
        qr{Queue IN \('$general_id', '$support_id'\).+Status IN \('new', 'open'\)},
);

my $tickets = RT::Tickets->new( RT->SystemUser );
for my $query ( sort keys %ticketsql ) {
    $tickets->FromSQL($query);
    like( $tickets->BuildSelectQuery, $ticketsql{$query}, qq{TicketSQL "$query" uses IN} );
}

done_testing;
