#line 1 "inc/Module/Install/Base.pm - /usr/lib/perl5/site_perl/5.8.7/Module/Install/Base.pm"
package Module::Install::Base;

# Suspend handler for "redefined" warnings
BEGIN {
	my $w = $SIG{__WARN__};
	$SIG{__WARN__} = sub { $w };
}

#line 36

sub new {
    my ($class, %args) = @_;

    foreach my $method (qw(call load)) {
        *{"$class\::$method"} = sub {
            +shift->_top->$method(@_);
        } unless defined &{"$class\::$method"};
    }

    bless(\%args, $class);
}

#line 56

sub AUTOLOAD {
    my $self = shift;

    local $@;
    my $autoload = eval { $self->_top->autoload } or return;
    goto &$autoload;
}

#line 72

sub _top { $_[0]->{_top} }

#line 85

sub admin {
    $_[0]->_top->{admin} or Module::Install::Base::FakeAdmin->new;
}

sub is_admin {
    $_[0]->admin->VERSION;
}

sub DESTROY {}

package Module::Install::Base::FakeAdmin;

my $Fake;
sub new { $Fake ||= bless(\@_, $_[0]) }

sub AUTOLOAD {}

sub DESTROY {}

# Restore warning handler
BEGIN {
	$SIG{__WARN__} = $SIG{__WARN__}->();
}

1;

#line 134
