# Copyright (c) Green Smoked Socks Productions y2k

# Wow, this file even have a POD.  See below.  It will eventually appear on
# CPAN some day.

package CGI::ApacheWrapper;

use vars qw($VERSION);

$VERSION="0.01";

# Usage: CGI::ApacheWrapper->new(CGI->new)
# ...eventually CGI::ApacheWrapper->new(CGI->new, {someoption=>1})

sub new {
    # Just the standard crap:
    my $object_or_class = shift; 
    my $class = ref($object_or_class) || $object_or_class;
    my $self={};
    bless $self, $class;
    $self->_init(@_) || die "Usage: \$self->new(CGI-object)";
    return $self;
}

sub _init {
    my $self=shift;
    $self->{_cgi_obj}=shift;
}

sub uri {
    # return $ENV{REQUEST_URI};    
    my $self=shift;
    return $self->{_cgi_obj}->url(-path_info=>1);
}

# TODO: I'm not really sure if "args" only should return the query
# string in a get query, or if it also should return a posted query.

sub args {
    my $self = shift;
    return (wantarray) ? 
	$self->{_cgi_obj}->Vars : 
	$self->{_cgi_obj}->query_string;
}

__END__

=head1 NAME

CGI::ApacheWrapper - A wrapper for an Apache request object

=head1 DESCRIPTION

mod_perl is very popular, and many packages requires it more or less.
This package should be a wrapper that can be used in a CGI environment
to run mod_perl handlers.

=head1 BUGS

This package is under construction, it's not complete, and maybe it
will never become complete.  I will just add features in the speed I
need it myself, and/or in the speed I get patches.

This package partly uses the CGI object, and partly the ENV
parameters.  It should be done cleaner; using only one of the two.
I'd almost daresay it might make sense to use the ENV to avoid too
much overhead.

=head1 AUTHOR

Tobias Brox <tobix@fsck.com> - all feedback is welcome.  There will
eventually be set up a mailinglist if enough people are interessted.
