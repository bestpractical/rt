package RT::Shredder::Plugin::Base::Dump;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::Base);

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub Type { return 'dump' }
sub AppliesToStates { return () }
sub SupportArgs { return () }

sub PushMark { return 1 }
sub PopMark { return 1 }
sub RollbackTo { return 1 }

1;
