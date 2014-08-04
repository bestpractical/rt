package RT::Action::Foo::Bar;

use strict;
use warnings;
use base 'RT::Action';

sub Prepare { return 1 }

sub Commit { return 1 }

1;
