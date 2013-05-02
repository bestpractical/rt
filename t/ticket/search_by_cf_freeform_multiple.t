
use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;

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

my $ylong = "y" x 300;
subtest "Creating tickets" => sub {
    RT::Test->create_tickets( { Queue => $q->id },
        { Subject => '-' },
        { Subject => 'x', "CustomField-$cf_id" => 'x', },
        { Subject => 'y', "CustomField-$cf_id" => 'y', },
        { Subject => 'z', "CustomField-$cf_id" => 'z', },
        { Subject => 'xy', "CustomField-$cf_id" => [ 'x', 'y' ], },
        { Subject => 'xz', "CustomField-$cf_id" => [ 'x', 'z' ], },
        { Subject => 'yz', "CustomField-$cf_id" => [ 'y', 'z' ], },
        { Subject => 'x_ylong', "CustomField-$cf_id" => [ 'x', $ylong ], },
        { Subject => 'ylong', "CustomField-$cf_id" => $ylong, },
    );
};

my @tests = (
    "CF.{$cf_id} IS NULL"                      => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id}.Content IS NULL"              => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.LargeContent IS NULL"         => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}' IS NULL"                  => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.{$cf_name}.Content' IS NULL"          => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "'CF.{$cf_name}.LargeContent' IS NULL"     => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_id}' IS NULL"             => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_name}' IS NULL"           => { '-' => 1, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },

    "CF.{$cf_id} IS NOT NULL"                  => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.Content IS NOT NULL"          => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "CF.{$cf_id}.LargeContent IS NOT NULL"     => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "'CF.{$cf_name}' IS NOT NULL"              => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.{$cf_name}.Content' IS NOT NULL"      => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}.LargeContent' IS NOT NULL" => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "'CF.$queue.{$cf_id}' IS NOT NULL"         => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.$queue.{$cf_name}' IS NOT NULL"       => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },

    "CF.{$cf_id} = 'x'"                   => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "CF.{$cf_id}.Content = 'x'"           => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "CF.{$cf_id}.LargeContent = 'x'"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id} = '$ylong'"              => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.Content = '$ylong'"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id}.LargeContent = '$ylong'" => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id} LIKE 'yyy'"              => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.Content LIKE 'yyy'"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id}.LargeContent LIKE 'yyy'" => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 1, ylong => 1 },
    "'CF.{$cf_name}' = 'x'"               => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}.Content' = 'x'"       => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}.LargeContent' = 'x'"  => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x'"          => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x'"        => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },

    "CF.{$cf_id} != 'x'"                   => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },
    "CF.{$cf_id}.Content != 'x'"           => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },
    "CF.{$cf_id}.LargeContent != 'x'"      => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id} != '$ylong'"              => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id}.Content != '$ylong'"      => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.LargeContent != '$ylong'" => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 0, ylong => 0 },
"TODO: CF.{$cf_id} NOT LIKE 'yyy'"         => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 0, ylong => 0 },
    "CF.{$cf_id}.Content NOT LIKE 'yyy'"   => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "CF.{$cf_id}.LargeContent NOT LIKE 'yyy'" => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 0, ylong => 0 },
    "'CF.{$cf_name}' != 'x'"               => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },
    "'CF.{$cf_name}.Content' != 'x'"       => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },
    "'CF.{$cf_name}.LargeContent' != 'x'"  => { '-' => 1, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.$queue.{$cf_id}' != 'x'"          => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },
    "'CF.$queue.{$cf_name}' != 'x'"        => { '-' => 1, x => 0, y => 1, z => 1, xy => 0, xz => 0, yz => 1, x_ylong => 0, ylong => 1 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} = 'y'"                        => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' = 'y'"                => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' = 'y'"      => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' = 'y'"  => { '-' => 0, x => 1, y => 1, z => 0, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 0 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} = 'y'"                        => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' = 'y'"                => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' = 'y'"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' = 'y'"  => { '-' => 0, x => 0, y => 0, z => 0, xy => 1, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },

    "CF.{$cf_id} != 'x' AND CF.{$cf_id} != 'y'"                        => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 1 },
    "'CF.{$cf_name}' != 'x' AND 'CF.{$cf_name}' != 'y'"                => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 1 },
    "'CF.$queue.{$cf_id}' != 'x' AND 'CF.$queue.{$cf_id}' != 'y'"      => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 1 },
    "'CF.$queue.{$cf_name}' != 'x' AND 'CF.$queue.{$cf_name}' != 'y'"  => { '-' => 1, x => 0, y => 0, z => 1, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 1 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} IS NULL"                        => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' IS NULL"                => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' IS NULL"      => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' IS NULL"  => { '-' => 0, x => 0, y => 0, z => 0, xy => 0, xz => 0, yz => 0, x_ylong => 0, ylong => 0 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} IS NULL"                        => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' IS NULL"                => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' IS NULL"      => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' IS NULL"  => { '-' => 1, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },

    "CF.{$cf_id} = 'x' AND CF.{$cf_id} IS NOT NULL"                        => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.{$cf_name}' = 'x' AND 'CF.{$cf_name}' IS NOT NULL"                => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_id}' = 'x' AND 'CF.$queue.{$cf_id}' IS NOT NULL"      => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },
    "'CF.$queue.{$cf_name}' = 'x' AND 'CF.$queue.{$cf_name}' IS NOT NULL"  => { '-' => 0, x => 1, y => 0, z => 0, xy => 1, xz => 1, yz => 0, x_ylong => 1, ylong => 0 },

    "CF.{$cf_id} = 'x' OR CF.{$cf_id} IS NOT NULL"                        => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.{$cf_name}' = 'x' OR 'CF.{$cf_name}' IS NOT NULL"                => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.$queue.{$cf_id}' = 'x' OR 'CF.$queue.{$cf_id}' IS NOT NULL"      => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
    "'CF.$queue.{$cf_name}' = 'x' OR 'CF.$queue.{$cf_name}' IS NOT NULL"  => { '-' => 0, x => 1, y => 1, z => 1, xy => 1, xz => 1, yz => 1, x_ylong => 1, ylong => 1 },
);
run_tests(@tests);


sub run_tests {
    my @tests = @_;
    while (@tests) {
        my $query = shift @tests;
        my %results = %{ shift @tests };
        local $TODO = "Not implemented correctly" if $query =~ s/^TODO:\s*//;
        subtest $query => sub {
            my $tix = RT::Tickets->new(RT->SystemUser);
            $tix->FromSQL( "$query" );

            my $error = 0;

            my $count = 0;
            $count++ foreach grep $_, values %results;
            is($tix->Count, $count, "found correct number of ticket(s)") or $error = 1;

            my $good_tickets = ($tix->Count == $count);
            while ( my $ticket = $tix->Next ) {
                next if $results{ $ticket->Subject };
                diag $ticket->Subject ." ticket has been found when it's not expected";
                $good_tickets = 0;
            }
            ok( $good_tickets, "all tickets are good" ) or $error = 1;

            diag "Wrong SQL: ". $tix->BuildSelectQuery if $error;
        };
    }
}


done_testing;
