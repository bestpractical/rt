#line 1
package Module::Install::Include;

use strict;
use Module::Install::Base;

use vars qw{$VERSION $ISCORE @ISA};
BEGIN {
	$VERSION = '0.65';
	$ISCORE  = 1;
	@ISA     = qw{Module::Install::Base};
}

sub include {
	shift()->admin->include(@_);
}

sub include_deps {
	shift()->admin->include_deps(@_);
}

sub auto_include {
	shift()->admin->auto_include(@_);
}

sub auto_include_deps {
	shift()->admin->auto_include_deps(@_);
}

sub auto_include_dependent_dists {
	shift()->admin->auto_include_dependent_dists(@_);
}

1;
