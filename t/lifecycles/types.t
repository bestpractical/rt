use strict;
use warnings;

BEGIN {require  './t/lifecycles/utils.pl'};

is_deeply( [ RT::Lifecycle->ListAll ], [qw/ approvals default delivery /],
       "Get the list of all lifecycles (implicitly for for tickets)");
is_deeply( [ RT::Lifecycle->ListAll('ticket') ],  [qw/ approvals default delivery /],
       "Get the list of all lifecycles for tickets");
is_deeply( [ RT::Lifecycle->List], [qw/ default delivery /],
       "Get the list of lifecycles without approvals (implicitly for for tickets)");
is_deeply( [ RT::Lifecycle->List('ticket') ],  [qw/ default delivery /],
       "Get the list of lifecycles without approvals for tickets");
is_deeply( [ RT::Lifecycle->List('racecar') ], [qw/ racing /],
       "Get the list of lifecycles for other types");

my $tickets = RT::Lifecycle->Load( Name => '', Type => 'ticket' );
ok($tickets, "Got a generalized lifecycle for tickets");
isa_ok( $tickets, "RT::Lifecycle::Ticket", "Is the right subclass" );
is_deeply( [ sort $tickets->Valid ],
           [ sort qw(new open stalled resolved rejected deleted ordered),
             'on way', 'delayed', 'delivered' ],
           "Only gets ticket statuses" );


my $racecars = RT::Lifecycle->Load( Name => '', Type => 'racecar' );
ok($racecars, "Got a generalized lifecycle for racecars");
isa_ok( $racecars, "RT::Lifecycle", "Is the generalized subclass" );
is_deeply( [ sort $racecars->Valid ],
           [ sort ('on-your-mark', 'get-set', 'go', 'first', 'second', 'third', 'no-place') ],
           "Only gets racecar statuses" );

done_testing;
