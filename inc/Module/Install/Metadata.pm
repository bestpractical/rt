#line 1
package Module::Install::Metadata;

use strict 'vars';
use Module::Install::Base;

use vars qw{$VERSION $ISCORE @ISA};
BEGIN {
	$VERSION = '0.72';
	$ISCORE  = 1;
	@ISA     = qw{Module::Install::Base};
}

my @scalar_keys = qw{
	name
	module_name
	abstract
	author
	version
	license
	distribution_type
	perl_version
	tests
	installdirs
};

my @tuple_keys = qw{
	configure_requires
	build_requires
	requires
	recommends
	bundles
};

sub Meta            { shift        }
sub Meta_ScalarKeys { @scalar_keys }
sub Meta_TupleKeys  { @tuple_keys  }

foreach my $key (@scalar_keys) {
	*$key = sub {
		my $self = shift;
		return $self->{values}{$key} if defined wantarray and !@_;
		$self->{values}{$key} = shift;
		return $self;
	};
}

sub requires {
	my $self = shift;
	while ( @_ ) {
		my $module  = shift or last;
		my $version = shift || 0;
		push @{ $self->{values}->{requires} }, [ $module, $version ];
	}
	$self->{values}{requires};
}

sub build_requires {
	my $self = shift;
	while ( @_ ) {
		my $module  = shift or last;
		my $version = shift || 0;
		push @{ $self->{values}->{build_requires} }, [ $module, $version ];
	}
	$self->{values}{build_requires};
}

sub configure_requires {
	my $self = shift;
	while ( @_ ) {
		my $module  = shift or last;
		my $version = shift || 0;
		push @{ $self->{values}->{configure_requires} }, [ $module, $version ];
	}
	$self->{values}{configure_requires};
}

sub recommends {
	my $self = shift;
	while ( @_ ) {
		my $module  = shift or last;
		my $version = shift || 0;
		push @{ $self->{values}->{recommends} }, [ $module, $version ];
	}
	$self->{values}{recommends};
}

sub bundles {
	my $self = shift;
	while ( @_ ) {
		my $module  = shift or last;
		my $version = shift || 0;
		push @{ $self->{values}->{bundles} }, [ $module, $version ];
	}
	$self->{values}{bundles};
}

# Aliases for build_requires that will have alternative
# meanings in some future version of META.yml.
sub test_requires      { shift->build_requires(@_) }
sub install_requires   { shift->build_requires(@_) }

# Aliases for installdirs options
sub install_as_core    { $_[0]->installdirs('perl')   }
sub install_as_cpan    { $_[0]->installdirs('site')   }
sub install_as_site    { $_[0]->installdirs('site')   }
sub install_as_vendor  { $_[0]->installdirs('vendor') }

sub sign {
	my $self = shift;
	return $self->{'values'}{'sign'} if defined wantarray and ! @_;
	$self->{'values'}{'sign'} = ( @_ ? $_[0] : 1 );
	return $self;
}

sub dynamic_config {
	my $self = shift;
	unless ( @_ ) {
		warn "You MUST provide an explicit true/false value to dynamic_config, skipping\n";
		return $self;
	}
	$self->{values}{dynamic_config} = $_[0] ? 1 : 0;
	return $self;
}

sub all_from {
	my ( $self, $file ) = @_;

	unless ( defined($file) ) {
		my $name = $self->name
			or die "all_from called with no args without setting name() first";
		$file = join('/', 'lib', split(/-/, $name)) . '.pm';
		$file =~ s{.*/}{} unless -e $file;
		die "all_from: cannot find $file from $name" unless -e $file;
	}

	# Some methods pull from POD instead of code.
	# If there is a matching .pod, use that instead
	my $pod = $file;
	$pod =~ s/\.pm$/.pod/i;
	$pod = $file unless -e $pod;

	# Pull the different values
	$self->name_from($file)         unless $self->name;
	$self->version_from($file)      unless $self->version;
	$self->perl_version_from($file) unless $self->perl_version;
	$self->author_from($pod)        unless $self->author;
	$self->license_from($pod)       unless $self->license;
	$self->abstract_from($pod)      unless $self->abstract;

	return 1;
}

sub provides {
	my $self     = shift;
	my $provides = ( $self->{values}{provides} ||= {} );
	%$provides = (%$provides, @_) if @_;
	return $provides;
}

sub auto_provides {
	my $self = shift;
	return $self unless $self->is_admin;
	unless (-e 'MANIFEST') {
		warn "Cannot deduce auto_provides without a MANIFEST, skipping\n";
		return $self;
	}
	# Avoid spurious warnings as we are not checking manifest here.
	local $SIG{__WARN__} = sub {1};
	require ExtUtils::Manifest;
	local *ExtUtils::Manifest::manicheck = sub { return };

	require Module::Build;
	my $build = Module::Build->new(
		dist_name    => $self->name,
		dist_version => $self->version,
		license      => $self->license,
	);
	$self->provides( %{ $build->find_dist_packages || {} } );
}

sub feature {
	my $self     = shift;
	my $name     = shift;
	my $features = ( $self->{values}{features} ||= [] );
	my $mods;

	if ( @_ == 1 and ref( $_[0] ) ) {
		# The user used ->feature like ->features by passing in the second
		# argument as a reference.  Accomodate for that.
		$mods = $_[0];
	} else {
		$mods = \@_;
	}

	my $count = 0;
	push @$features, (
		$name => [
			map {
				ref($_) ? ( ref($_) eq 'HASH' ) ? %$_ : @$_ : $_
			} @$mods
		]
	);

	return @$features;
}

sub features {
	my $self = shift;
	while ( my ( $name, $mods ) = splice( @_, 0, 2 ) ) {
		$self->feature( $name, @$mods );
	}
	return $self->{values}->{features}
		? @{ $self->{values}->{features} }
		: ();
}

sub no_index {
	my $self = shift;
	my $type = shift;
	push @{ $self->{values}{no_index}{$type} }, @_ if $type;
	return $self->{values}{no_index};
}

sub read {
	my $self = shift;
	$self->include_deps( 'YAML::Tiny', 0 );

	require YAML::Tiny;
	my $data = YAML::Tiny::LoadFile('META.yml');

	# Call methods explicitly in case user has already set some values.
	while ( my ( $key, $value ) = each %$data ) {
		next unless $self->can($key);
		if ( ref $value eq 'HASH' ) {
			while ( my ( $module, $version ) = each %$value ) {
				$self->can($key)->($self, $module => $version );
			}
		} else {
			$self->can($key)->($self, $value);
		}
	}
	return $self;
}

sub write {
	my $self = shift;
	return $self unless $self->is_admin;
	$self->admin->write_meta;
	return $self;
}

sub version_from {
	require ExtUtils::MM_Unix;
	my ( $self, $file ) = @_;
	$self->version( ExtUtils::MM_Unix->parse_version($file) );
}

sub abstract_from {
	require ExtUtils::MM_Unix;
	my ( $self, $file ) = @_;
	$self->abstract(
		bless(
			{ DISTNAME => $self->name },
			'ExtUtils::MM_Unix'
		)->parse_abstract($file)
	 );
}

sub name_from {
	my $self = shift;
	if (
		Module::Install::_read($_[0]) =~ m/
		^ \s*
		package \s*
		([\w:]+)
		\s* ;
		/ixms
	) {
		my $name = $1;
		$name =~ s{::}{-}g;
		$self->name($name);
	} else {
		die "Cannot determine name from $_[0]\n";
		return;
	}
}

sub perl_version_from {
	my $self = shift;
	if (
		Module::Install::_read($_[0]) =~ m/
		^
		use \s*
		v?
		([\d_\.]+)
		\s* ;
		/ixms
	) {
		my $perl_version = $1;
		$perl_version =~ s{_}{}g;
		$self->perl_version($perl_version);
	} else {
		warn "Cannot determine perl version info from $_[0]\n";
		return;
	}
}

sub author_from {
	my $self    = shift;
	my $content = Module::Install::_read($_[0]);
	if ($content =~ m/
		=head \d \s+ (?:authors?)\b \s*
		([^\n]*)
		|
		=head \d \s+ (?:licen[cs]e|licensing|copyright|legal)\b \s*
		.*? copyright .*? \d\d\d[\d.]+ \s* (?:\bby\b)? \s*
		([^\n]*)
	/ixms) {
		my $author = $1 || $2;
		$author =~ s{E<lt>}{<}g;
		$author =~ s{E<gt>}{>}g;
		$self->author($author);
	} else {
		warn "Cannot determine author info from $_[0]\n";
	}
}

sub license_from {
	my $self = shift;
	if (
		Module::Install::_read($_[0]) =~ m/
		(
			=head \d \s+
			(?:licen[cs]e|licensing|copyright|legal)\b
			.*?
		)
		(=head\\d.*|=cut.*|)
		\z
	/ixms ) {
		my $license_text = $1;
		my @phrases      = (
			'under the same (?:terms|license) as perl itself' => 'perl',        1,
			'GNU public license'                              => 'gpl',         1,
			'GNU lesser public license'                       => 'lgpl',        1,
			'BSD license'                                     => 'bsd',         1,
			'Artistic license'                                => 'artistic',    1,
			'GPL'                                             => 'gpl',         1,
			'LGPL'                                            => 'lgpl',        1,
			'BSD'                                             => 'bsd',         1,
			'Artistic'                                        => 'artistic',    1,
			'MIT'                                             => 'mit',         1,
			'proprietary'                                     => 'proprietary', 0,
		);
		while ( my ($pattern, $license, $osi) = splice(@phrases, 0, 3) ) {
			$pattern =~ s{\s+}{\\s+}g;
			if ( $license_text =~ /\b$pattern\b/i ) {
				if ( $osi and $license_text =~ /All rights reserved/i ) {
					warn "LEGAL WARNING: 'All rights reserved' may invalidate Open Source licenses. Consider removing it.";
				}
				$self->license($license);
				return 1;
			}
		}
	}

	warn "Cannot determine license info from $_[0]\n";
	return 'unknown';
}

sub install_script {
	my $self = shift;
	my $args = $self->makemaker_args;
	my $exe  = $args->{EXE_FILES} ||= [];
        foreach ( @_ ) {
		if ( -f $_ ) {
			push @$exe, $_;
		} elsif ( -d 'script' and -f "script/$_" ) {
			push @$exe, "script/$_";
		} else {
			die "Cannot find script '$_'";
		}
	}
}

1;
