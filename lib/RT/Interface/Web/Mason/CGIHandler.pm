package RT::Interface::Web::Mason::CGIHandler;

use strict;
use warnings;

# use base fails here (see rt3.fsck.com#12555)
require HTML::Mason::CGIHandler;
our @ISA = qw(HTML::Mason::CGIHandler);
use RT::Interface::Web::Mason::HandlerMixin;

1;
