#line 1 "inc/Module/Install.pm - /usr/local/share/perl/5.8.4/Module/Install.pm"
package Module::Install;
$VERSION = '0.36';

die << "." unless $INC{join('/', inc => split(/::/, __PACKAGE__)).'.pm'};
Please invoke ${\__PACKAGE__} with:

    use inc::${\__PACKAGE__};

not:

    use ${\__PACKAGE__};

.

use strict 'vars';
use Cwd ();
use File::Find ();
use File::Path ();

@inc::Module::Install::ISA = 'Module::Install';
*inc::Module::Install::VERSION = *VERSION;

#line 129

sub import {
    my $class = shift;
    my $self = $class->new(@_);

    if (not -f $self->{file}) {
        require "$self->{path}/$self->{dispatch}.pm";
        File::Path::mkpath("$self->{prefix}/$self->{author}");
        $self->{admin} = 
          "$self->{name}::$self->{dispatch}"->new(_top => $self);
        $self->{admin}->init;
        @_ = ($class, _self => $self);
        goto &{"$self->{name}::import"};
    }

    *{caller(0) . "::AUTOLOAD"} = $self->autoload;

    # Unregister loader and worker packages so subdirs can use them again
    delete $INC{"$self->{file}"};
    delete $INC{"$self->{path}.pm"};
}

#line 156

sub autoload {
    my $self = shift;
    my $caller = caller;

    my $cwd = Cwd::cwd();
    my $sym = "$caller\::AUTOLOAD";

    $sym->{$cwd} = sub {
        my $pwd = Cwd::cwd();
        if (my $code = $sym->{$pwd}) {
            goto &$code unless $cwd eq $pwd; # delegate back to parent dirs
        }
        $$sym =~ /([^:]+)$/ or die "Cannot autoload $caller";
        unshift @_, ($self, $1);
        goto &{$self->can('call')} unless uc($1) eq $1;
    };
}

#line 181

sub new {
    my ($class, %args) = @_;

    return $args{_self} if $args{_self};

    $args{dispatch} ||= 'Admin';
    $args{prefix}   ||= 'inc';
    $args{author}   ||= '.author';
    $args{bundle}   ||= 'inc/BUNDLES';

    $class =~ s/^\Q$args{prefix}\E:://;
    $args{name}     ||= $class;
    $args{version}  ||= $class->VERSION;

    unless ($args{path}) {
        $args{path}  = $args{name};
        $args{path}  =~ s!::!/!g;
    }
    $args{file}     ||= "$args{prefix}/$args{path}.pm";

    bless(\%args, $class);
}

#line 210

sub call {
    my $self   = shift;
    my $method = shift;
    my $obj = $self->load($method) or return;

    unshift @_, $obj;
    goto &{$obj->can($method)};
}

#line 225

sub load {
    my ($self, $method) = @_;

    $self->load_extensions(
        "$self->{prefix}/$self->{path}", $self
    ) unless $self->{extensions};

    foreach my $obj (@{$self->{extensions}}) {
        return $obj if $obj->can($method);
    }

    my $admin = $self->{admin} or die << "END";
The '$method' method does not exist in the '$self->{prefix}' path!
Please remove the '$self->{prefix}' directory and run $0 again to load it.
END

    my $obj = $admin->load($method, 1);
    push @{$self->{extensions}}, $obj;

    $obj;
}

#line 255

sub load_extensions {
    my ($self, $path, $top_obj) = @_;

    unshift @INC, $self->{prefix}
        unless grep { $_ eq $self->{prefix} } @INC;

    local @INC = ($path, @INC);
    foreach my $rv ($self->find_extensions($path)) {
        my ($file, $pkg) = @{$rv};
        next if $self->{pathnames}{$pkg};

        eval { require $file; 1 } or (warn($@), next);
        $self->{pathnames}{$pkg} = delete $INC{$file};
        push @{$self->{extensions}}, $pkg->new( _top => $top_obj );
    }
}

#line 279

sub find_extensions {
    my ($self, $path) = @_;
    my @found;

    File::Find::find(sub {
        my $file = $File::Find::name;
        return unless $file =~ m!^\Q$path\E/(.+)\.pm\Z!is;
        return if $1 eq $self->{dispatch};

        $file = "$self->{path}/$1.pm";
        my $pkg = "$self->{name}::$1"; $pkg =~ s!/!::!g;
        push @found, [$file, $pkg];
    }, $path) if -d $path;

    @found;
}

1;

__END__

#line 617
