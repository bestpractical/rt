#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test nodata => 1, tests => 118;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

diag "create a CF";
my ($cf_name, $cf_id, $cf) = ("Test", 0, undef);
{
    $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $q->id,
        Type  => 'FreeformMultiple',
    );
    ok($ret, "Custom Field Order created");
    $cf_id = $cf->id;
}

my ($total, @data, @tickets, %test) = (0, ());

sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Tickets->new(RT->SystemUser);
        $tix->FromSQL( "( $query_prefix ) AND ( $key )" );

        my $error = 0;

        my $count = 0;
        $count++ foreach grep $_, values %{ $test{$key} };
        is($tix->Count, $count, "found correct number of ticket(s) by '$key'") or $error = 1;

        my $good_tickets = ($tix->Count == $count);
        while ( my $ticket = $tix->Next ) {
            next if $test{$key}->{ $ticket->Subject };
            diag $ticket->Subject ." ticket has been found when it's not expected";
            $good_tickets = 0;
        }
        ok( $good_tickets, "all tickets are good with '$key'" ) or $error = 1;

        diag "Wrong SQL query for '$key':". $tix->BuildSelectQuery if $error;
    }
}

@data = (
    { Subject => '-' },
    { Subject => 'x', "CustomField-$cf_id" => 'x', },
    { Subject => 'y', "CustomField-$cf_id" => 'y', },
    { Subject => 'z', "CustomField-$cf_id" => 'z', },
    { Subject => 'xy', "CustomField-$cf_id" => [ 'x', 'y' ], },
    { Subject => 'xz', "CustomField-$cf_id" => [ 'x', 'z' ], },
    { Subject => 'yz', "CustomField-$cf_id" => [ 'y', 'z' ], },
);
%test = (
    "CF.{$cf_id} IS NULL"                 => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.{$cf_name}' IS NULL"             => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_id}' IS NULL"        => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_name}' IS NULL"      => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },

    "CF.{$cf_id} IS NOT NULL"             => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.{$cf_name}' IS NOT NULL"         => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_id}' IS NOT NULL"    => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_name}' IS NOT NULL"  => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },

    "CF.{$cf_id} = 'x'"                   => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.{$cf_name}' = 'x'"               => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_id}' = 'x'"          => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_name}' = 'x'"        => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },

    "CF.{$cf_id} != 'x'"                  => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1 },
    "'CF.{$cf_name}' != 'x'"              => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1 },
    "'CF.$queue.{$cf_id}' != 'x'"         => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1 },
    "'CF.$queue.{$cf_name}' != 'x'"       => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} = 'y'"                        => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' = 'y'"                => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' = 'y'"      => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' = 'y'"  => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} = 'y'"                        => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' = 'y'"                => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' = 'y'"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' = 'y'"  => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0 },

    "CF.{$cf_id} != 'x' AND CF.{$cf_id} != 'y'"                        => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0 },
    "'CF.{$cf_name}' != 'x' AND 'CF.{$cf_name}' != 'y'"                => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_id}' != 'x' AND 'CF.$queue.{$cf_id}' != 'y'"      => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_name}' != 'x' AND 'CF.$queue.{$cf_name}' != 'y'"  => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} IS NULL"                        => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' IS NULL"                => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' IS NULL"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' IS NULL"  => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} IS NULL"                        => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' IS NULL"                => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' IS NULL"      => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' IS NULL"  => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} IS NOT NULL"                        => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' IS NOT NULL"                => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' IS NOT NULL"      => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' IS NOT NULL"  => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} IS NOT NULL"                        => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' IS NOT NULL"                => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' IS NOT NULL"      => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' IS NOT NULL"  => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1 },
);
@tickets = RT::Test->create_tickets( { Queue => $q->id }, @data);
$total = scalar @tickets;

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();

