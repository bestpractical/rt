use strict;
use warnings;

use RT::Test tests => 'no_declare';

# This test script processes the sample initialdata file in
# ../data/initialdata/initialdata
# To add initialdata tests, add the data to the initialdata file and it
# will be processed by this script.

my $initialdata = RT::Test::get_relocatable_file("initialdata" => "..", "data", "initialdata");
my ($rv, $msg) = RT->DatabaseHandle->InsertData( $initialdata, undef, disconnect_after => 0 );
ok($rv, "Inserted test data from $initialdata")
    or diag "Error: $msg";

done_testing();