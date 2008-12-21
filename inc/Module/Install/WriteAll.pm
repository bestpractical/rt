#line 1
package Module::Install::WriteAll;

use strict;
use Module::Install::Base;

use vars qw{$VERSION @ISA $ISCORE};
BEGIN {
	$VERSION = '0.77';
	@ISA     = qw{Module::Install::Base};
	$ISCORE  = 1;
}

sub WriteAll {
	my $self = shift;
	my %args = (
		meta        => 1,
		sign        => 0,
		inline      => 0,
		check_nmake => 1,
		@_,
	);

	$self->sign(1)                if $args{sign};
	$self->Meta->write            if $args{meta};
	$self->admin->WriteAll(%args) if $self->is_admin;

	$self->check_nmake if $args{check_nmake};
	unless ( $self->makemaker_args->{PL_FILES} ) {
		$self->makemaker_args( PL_FILES => {} );
	}

	if ( $args{inline} ) {
		$self->Inline->write;
	} else {
		$self->Makefile->write;
	}
}

1;
