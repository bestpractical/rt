#line 1 "inc/Module/Install/Metadata.pm - /usr/local/share/perl/5.8.4/Module/Install/Metadata.pm"
package Module::Install::Metadata;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$VERSION = '0.04';

use strict 'vars';
use vars qw($VERSION);

sub Meta { shift }

my @scalar_keys = qw(
    name module_name version abstract author license
    distribution_type sign perl_version
);
my @tuple_keys  = qw(build_requires requires recommends bundles);

foreach my $key (@scalar_keys) {
    *$key = sub {
        my $self = shift;
        return $self->{'values'}{$key} unless @_;
        $self->{'values'}{$key} = shift;
        return $self;
    };
}

foreach my $key (@tuple_keys) {
    *$key = sub {
        my $self = shift;
        return $self->{'values'}{$key} unless @_;
        my @rv;
        while (@_) {
            my $module  = shift or last;
            my $version = shift || 0;
            if ($module eq 'perl') {
                $version =~ s{^(\d+)\.(\d+)\.(\d+)}
                             {$1 + $2/1_000 + $3/1_000_000}e;
                $self->perl_version($version);
                next;
            }
            my $rv = [$module, $version];
            push @{$self->{'values'}{$key}}, $rv;
            push @rv, $rv;
        }
        return @rv;
    };
}

sub features {
    my $self = shift;
    while (my ($name, $mods) = splice(@_, 0, 2)) {
        my $count = 0;
        push @{$self->{'values'}{'features'}}, ($name => [
            map { (++$count % 2 and ref($_) and ($count += $#$_)) ? @$_ : $_ } @$mods
        ] );
    }
    return @{$self->{'values'}{'features'}};
}

sub no_index {
    my $self = shift;
    my $type = shift;
    push @{$self->{'values'}{'no_index'}{$type}}, @_ if $type;
    return $self->{'values'}{'no_index'};
}

sub _dump {
    my $self = shift;
    my $package = ref($self->_top);
    my $version = $self->_top->VERSION;
    my %values = %{$self->{'values'}};

    delete $values{sign};
    if (my $perl_version = delete $values{perl_version}) {
        # Always canonical to three-dot version 
        $perl_version =~ s{^(\d+)\.(\d\d\d)(\d*)}{join('.', $1, int($2), int($3))}e
            if $perl_version >= 5.006;
        $values{requires} = [
            [perl => $perl_version],
            @{$values{requires}||[]},
        ];
    }

    warn "No license specified, setting license = 'unknown'\n"
        unless $values{license};

    $values{license} ||= 'unknown';
    $values{distribution_type} ||= 'module';
    $values{name} ||= do {
        my $name = $values{module_name};
        $name =~ s/::/-/g;
        $name;
    } if $values{module_name};

    if ($values{name} =~ /::/) {
        my $name = $values{name};
        $name =~ s/::/-/g;
        die "Error in name(): '$values{name}' should be '$name'!\n";
    }

    my $dump = '';
    foreach my $key (@scalar_keys) {
        $dump .= "$key: $values{$key}\n" if exists $values{$key};
    }
    foreach my $key (@tuple_keys) {
        next unless exists $values{$key};
        $dump .= "$key:\n";
        foreach (@{$values{$key}}) {
            $dump .= "  $_->[0]: $_->[1]\n";
        }
    }

    if (my $no_index = $values{no_index}) {
        push @{$no_index->{'directory'}}, 'inc';
        require YAML;
        local $YAML::UseHeader = 0;
        $dump .= YAML::Dump({ no_index => $no_index});
    }
    else {
        $dump .= << "META";
no_index:
  directory:
    - inc
META
    }
    
    $dump .= "generated_by: $package version $version\n";
    return $dump;
}

sub read {
    my $self = shift;
    $self->include_deps( 'YAML', 0 );
    require YAML;
    my $data = YAML::LoadFile( 'META.yml' );
    # Call methods explicitly in case user has already set some values.
    while ( my ($key, $value) = each %$data ) {
        next unless $self->can( $key );
        if (ref $value eq 'HASH') {
            while (my ($module, $version) = each %$value) {
                $self->$key( $module => $version );
            }
        }
        else {
            $self->$key( $value );
        }
    }
    return $self;
}

sub write {
    my $self = shift;
    return $self unless $self->is_admin;

    META_NOT_OURS: {
        local *FH;
        if (open FH, "META.yml") {
            while (<FH>) {
                last META_NOT_OURS if /^generated_by: Module::Install\b/;
            }
            return $self if -s FH;
        }
    }

    warn "Writing META.yml\n";
    open META, "> META.yml" or warn "Cannot write to META.yml: $!";
    print META $self->_dump;
    close META;
    return $self;
}

sub version_from {
    my ($self, $version_from) = @_;
    require ExtUtils::MM_Unix;
    $self->version(ExtUtils::MM_Unix->parse_version($version_from));
}

sub abstract_from {
    my ($self, $abstract_from) = @_;
    require ExtUtils::MM_Unix;
    $self->abstract(
        bless( { DISTNAME => $self->name }, 'ExtUtils::MM_Unix')
            ->parse_abstract($abstract_from)
    );
}

1;
