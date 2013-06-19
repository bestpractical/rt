
use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => "sorting" );
ok $queue && $queue->id, "Created queue";
my $queue_name = $queue->Name;

# CFs for testing, later we create another one
my $cf;
my $cf_name = "ordering";
diag "create a CF";
{
    $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field created");
}

run_tests(
    [
        { Subject => '-' },
        { Subject => 'aa', 'CustomField-' . $cf->id => 'aa' },
        { Subject => 'bb', 'CustomField-' . $cf->id => 'bb' },
        { Subject => 'cc', 'CustomField-' . $cf->id => 'cc' },
    ],
    {                                    Count => 4, Order => "CF.{$cf_name}"             },
    {                                    Count => 4, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_name} LIKE 'a'", Count => 1, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_name} LIKE 'a'", Count => 1, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_name} != 'cc'",  Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_name} != 'cc'",  Count => 3, Order => "CF.$queue_name.{$cf_name}" },
);



my $other_cf;
my $other_name = "othercf";
diag "create another CF";
{
    $other_cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $other_cf->Create(
        Name  => $other_name,
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Other Custom Field created");
}

# Test that order is not affected by other CFs
run_tests(
    [
        { Subject => '-', },
        { Subject => 'aa', "CustomField-" . $cf->id => 'aa', "CustomField-" . $other_cf->id => 'za' },
        { Subject => 'bb', "CustomField-" . $cf->id => 'bb', "CustomField-" . $other_cf->id => 'ya' },
        { Subject => 'cc', "CustomField-" . $cf->id => 'cc', "CustomField-" . $other_cf->id => 'xa' },
    ],
    {                                      Count => 4, Order => "CF.{$cf_name}"             },
    {                                      Count => 4, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_name} LIKE 'a'",   Count => 1, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_name} LIKE 'a'",   Count => 1, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_name} != 'cc'",    Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_name} != 'cc'",    Count => 3, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$other_name} != 'za'", Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$other_name} != 'za'", Count => 3, Order => "CF.$queue_name.{$cf_name}" },
);

# And then add a CF with a duplicate name, on a different queue
{
    my $other_queue = RT::Test->load_or_create_queue( Name => "other_queue" );
    ok $other_queue && $other_queue->id, "Created queue";

    my $dup = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $dup->Create(
        Name  => $cf_name,
        Queue => $other_queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field created");
}

my $cf_id = $cf->id;
run_tests(
    [
        { Subject => '-', },
        { Subject => 'aa', "CustomField-" . $cf->id => 'aa', "CustomField-" . $other_cf->id => 'za' },
        { Subject => 'bb', "CustomField-" . $cf->id => 'bb', "CustomField-" . $other_cf->id => 'ya' },
        { Subject => 'cc', "CustomField-" . $cf->id => 'cc', "CustomField-" . $other_cf->id => 'xa' },
    ],
    {                                                Count => 4, Order => "CF.{$cf_name}"             },
    {                                                Count => 4, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_id} LIKE 'a'",               Count => 1, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_id} LIKE 'a'",               Count => 1, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_id} != 'cc'",                Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$cf_id} != 'cc'",                Count => 3, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.$queue_name.{$cf_name} LIKE 'a'", Count => 1, Order => "CF.{$cf_name}"             },
    { Query => "CF.$queue_name.{$cf_name} LIKE 'a'", Count => 1, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.$queue_name.{$cf_name} != 'cc'",  Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.$queue_name.{$cf_name} != 'cc'",  Count => 3, Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$other_name} != 'za'",           Count => 3, Order => "CF.{$cf_name}"             },
    { Query => "CF.{$other_name} != 'za'",           Count => 3, Order => "CF.$queue_name.{$cf_name}" },

    { Query => "CF.{$cf_id} != 'cc'",                Count => 3, Order => "CF.{$cf_id}"               },
    { Query => "CF.{$cf_id} != 'cc'",                Count => 3, Order => "CF.$queue_name.{$cf_id}"   },
    { Query => "CF.$queue_name.{$cf_name} != 'cc'",  Count => 3, Order => "CF.{$cf_id}"               },
    { Query => "CF.$queue_name.{$cf_name} != 'cc'",  Count => 3, Order => "CF.$queue_name.{$cf_id}"   },
    { Query => "CF.{$other_name} != 'za'",           Count => 3, Order => "CF.{$cf_id}"               },
    { Query => "CF.{$other_name} != 'za'",           Count => 3, Order => "CF.$queue_name.{$cf_id}"   },
);

sub run_tests {
    my $tickets = shift;
    my @tickets = RT::Test->create_tickets( { Queue => $queue->id, RandomOrder => 1 }, @{ $tickets });
    my $base_query = join(" OR ", map {"id = ".$_->id} @tickets) || "id > 0";

    my @tests = @_;
    for my $test ( @tests ) {
        $test->{'Query'} ||= "id > 0";
        my $query = "( $base_query ) AND " . $test->{'Query'};
        for my $order (qw(ASC DESC)) {
            subtest $test->{'Query'} . " ORDER BY ".$test->{'Order'}. " $order" => sub {
                my $error = 0;
                my $tix = RT::Tickets->new( RT->SystemUser );
                $tix->FromSQL( $query );
                $tix->OrderBy( FIELD => $test->{'Order'}, ORDER => $order );

                is($tix->Count, $test->{'Count'}, "found right number of tickets (".$test->{Count}.")")
                    or $error = 1;

                my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
                if ($tix->Count) {
                    my $last_id = $tix->Last->id;
                    while ( my $t = $tix->Next ) {
                        my $tmp;
                        next if $t->id == $last_id and $t->Subject eq "-"; # Nulls are allowed to come last, in Pg

                        if ( $order eq 'ASC' ) {
                            $tmp = ((split( /,/, $last))[0] cmp (split( /,/, $t->Subject))[0]);
                        } else {
                            $tmp = -((split( /,/, $last))[-1] cmp (split( /,/, $t->Subject))[-1]);
                        }
                        if ( $tmp > 0 ) {
                            $order_ok = 0; last;
                        }
                        $last = $t->Subject;
                    }
                }

                ok( $order_ok, "$order order of tickets is good" )
                    or $error = 1;

                if ( $error ) {
                    diag "Wrong SQL query:". $tix->BuildSelectQuery;
                    $tix->GotoFirstItem;
                    while ( my $t = $tix->Next ) {
                        diag sprintf "%02d - %s", $t->id, $t->Subject;
                    }
                }
            };
        }
    }
}

done_testing;
