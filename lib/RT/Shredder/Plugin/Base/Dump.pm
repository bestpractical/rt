package RT::Shredder::Plugin::Base::Dump;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::Base);

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub Type { return 'dump' }

sub SupportArgs { return () }

1;
