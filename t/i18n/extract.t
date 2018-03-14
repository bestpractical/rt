use strict;
use warnings;

use RT::Test tests => undef, nodb => 1;

use RT::I18N::Extract;

my $extract = RT::I18N::Extract->new;
ok($extract);

my %PO = $extract->all;
ok(keys %PO, "Extracted keys successfully");

my @errors = $extract->errors;
diag "$_" for @errors;
ok(! @errors, "No errors during extraction");

done_testing;
