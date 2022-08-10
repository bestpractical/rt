use strict;
use warnings;

use RT::Test;

# Test the segment faults issue on DBD::Oracle 1.80+(before 1.90), which
# happens when there are multiple connections stored in package variables.
# Here we only need to create another one as $RT::Handle already has one.
our $handle = RT::Handle->new;
$handle->Connect;

done_testing;
