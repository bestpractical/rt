use strict;
use warnings;

use RT::Test tests => 2;

use constant KIDS => 50;

my $id;

{
    my $t = RT::Ticket->new( RT->SystemUser );
    ($id) = $t->Create(
        Queue => "General",
        Subject => "Race $$",
    );
}

diag "Created ticket $id";
RT->DatabaseHandle->Disconnect;

my @kids;
for (1..KIDS) {
    if (my $pid = fork()) {
        push @kids, $pid;
        next;
    }

    # In the kid, load up the ticket and correspond
    RT->ConnectToDatabase;
    my $t = RT::Ticket->new( RT->SystemUser );
    $t->Load( $id );
    $t->Correspond( Content => "Correspondence from PID $$" );
    undef $t;
    exit 0;
}


diag "Forked @kids";
waitpid $_, 0 for @kids;
diag "All kids finished corresponding";

RT->ConnectToDatabase;
my $t = RT::Ticket->new( RT->SystemUser );
$t->Load($id);
my $txns = $t->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Status' );
is($txns->Count, 1, "Only one transaction change recorded" );

$txns = $t->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
is($txns->Count, KIDS, "But all correspondences were recorded" );
