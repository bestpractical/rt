package HTML::Mason::CGIHandler;

use strict;

use HTML::Mason;
use CGI;
use Carp;
use File::Spec;
use Params::Validate qw(:all);

use HTML::Mason::Container;
use base qw(HTML::Mason::Container);

use HTML::Mason::MethodMaker
    ( read_write => [ qw( interp ) ] );


__PACKAGE__->valid_params
    (
     dev_dirs => {type => ARRAYREF, optional => 1},
     interp   => {isa => 'HTML::Mason::Interp'},
    );

__PACKAGE__->contained_objects
    (
     interp => 'HTML::Mason::Interp',
     cgi_request => { class   => 'HTML::Mason::FakeApache', # $r
		      delayed => 1 },
    );


sub new {
    my $package = shift;

    my @my_args = $package->create_contained_objects(comp_root => $ENV{DOCUMENT_ROOT},
						     request_class => 'HTML::Mason::Request::CGI',
						     error_mode => 'output',
						     error_format => 'html',
						     @_);

    my $self = bless { validate @my_args, $package->validation_spec };
    $self->interp->out_method(\$self->{output});
    $self->interp->compiler->add_allowed_globals('$r');
    
    return $self;
}

sub exec {
    my ($self, $component) = (shift, shift);
    local $self->{exec_args} = [@_];
    $self->_handler($component);
}

sub handle_request {
    my $self = shift;
    $self->_handler($ENV{PATH_INFO}, @_);
}

sub handle_cgi {
    my ($self, $component) = (shift, shift);
    $self->_handler($component, @_);
}

sub _handler {
    my ($self, $component) = (shift, shift);
    
    my ($local_root, $local_datadir);
    if ($self->{dev_dirs}) {
	foreach my $dir (@{$self->{dev_dirs}}) {
	    if ($component =~ s/^\Q$dir//) {
		$local_root    = File::Spec->catdir($self->interp->resolver->comp_root, $dir);
		$local_datadir = File::Spec->catdir($self->interp->data_dir, $dir);
		last;
	    }
	}
    }

    my $r = $self->create_delayed_object('cgi_request');
    $self->interp->set_global('$r', $r);

    $self->{output} = '';
    my @params = $self->{exec_args} ? @{$self->{exec_args}} : $r->params;

    my $old_root;
    if ($local_root) {
	$old_root = $self->interp->resolver->comp_root;
	$self->interp->resolver->comp_root($local_root);
    }

    my $old_datadir;
    if ($local_datadir) {
	$old_datadir = $self->interp->data_dir($local_datadir);
    }

    $self->interp->delayed_object_params('request', cgi_request => $r);
    eval { $self->interp->exec($component, @params) };
    # save it in case setting one of the attributes below uses eval{}
    my $e = $@;

    $self->interp->resolver->comp_root($old_root) if $old_root;
    $self->interp->data_dir($old_datadir) if $old_datadir;

    die $e if $e;

    if (@_) {
	# This is a secret feature, and should stay secret (or go away) because it's just a hack for the test suite.
	$_[0] .= $r->http_header . $self->{output};
    } else {
	print $r->http_header;
	print $self->{output};
    }
}

###########################################################
package HTML::Mason::Request::CGI;
# Subclass for HTML::Mason::Request object $m

use HTML::Mason::Request;
use base qw(HTML::Mason::Request);

__PACKAGE__->valid_params( cgi_request => {isa => 'HTML::Mason::FakeApache'} );

sub cgi_object {
    my $self = shift;
    return $self->{cgi_request}->query(@_);
}

###########################################################
package HTML::Mason::FakeApache;
# Analogous to Apache request object $r (but not an actual Apache subclass)

use HTML::Mason::MethodMaker(read_write => [qw(query headers)]);

sub new {
    my $class = shift;
    return bless {
		  query   => $RT::Mason::CGI,
		  headers => {},
		 }, $class;
}

sub header_out {
    my ($self, $header) = (shift, shift);

    return $self->_set_header($header, shift) if @_;
    return $self->headers->{$header};
}

sub content_type {
    my $self = shift;

    return $self->_set_header('Content-type', shift) if @_;
    return $self->headers->{'Content-type'};
}

sub _set_header {
    my ($self, $header, $value) = @_;
    delete $self->headers->{$header}, return unless defined $value;
    # CGI really wants a - before each header
    $header = "-".$header  unless ($header =~ /^-/);
    return $self->headers->{$header} = $value;
}

sub http_header {
    my $self = shift;
    my $method = exists $self->headers->{'-location'} ? 'redirect' : 'header';
    return $self->query->header(%{$self->headers});
}

sub params {
    my $self = shift;
    my @input = map {$_, [$self->query->param($_)]} $self->query->param;
    foreach (@input) {$_ = $_->[0] if ref($_) and @$_==1}  # Unwrap single-element array refs
    return @input;
}

1;

__END__

=head1 NAME

HTML::Mason::CGIHandler - Use Mason in a CGI environment

=head1 SYNOPSIS

In httpd.conf or .htaccess:

   Action html-mason /cgi-bin/mason_handler.cgi
   <FilesMatch "\.html$">
    SetHandler html-mason
   </FilesMatch>

A script at /cgi-bin/mason_handler.pl :

   #!/usr/bin/perl
   use HTML::Mason::CGIHandler;
   
   my $h = new HTML::Mason::CGIHandler
    (
     dev_dirs  => [qw(/cleetus /zeke)],
     data_dir  => '/home/jethro/code/mason_data',
     allow_globals => [qw(%session $u)],
    );
   
   $h->handle_request;

A .html component somewhere in the web server's document root:

   <%args>
    $mood => 'satisfied'
   </%args>
   % $r->header_out(Location => "http://blahblahblah.com/moodring/$mood.html");
   ...

=head1 DESCRIPTION

This module lets you execute Mason components in a CGI environment.
It lets you keep your top-level components in the web server's
document root, using regular component syntax and without worrying
about the particular details of invoking Mason on each request.

If you want to use Mason components from I<within> a regular CGI
script (or any other Perl program, for that matter), then you don't
need this module.  You can simply follow the directions in L<the
STANDALONE MODE section in
HTML::Mason::Interp|HTML::Mason::Interp/"STANDALONE MODE">.

This module also provides an C<$r> request object for use inside
components, similar to the Apache request object under
C<HTML::Mason::ApacheHandler>, but limited in functionality.

Finally, this module alters the C<HTML::Mason::Request> object C<$m> to
provide direct access to the CGI query, should such access be necessary.

=head2 C<HTML::Mason::CGIHandler> Methods

=over 4

=item * new()

Creates a new handler.  Accepts any parameter that the Interpreter
accepts, and also accepts a C<dev_dirs> parameter.  If a C<dev_dirs>
parameter is passed, it should contain an array reference of
directories that contain alternate copies of the entire site.  This
helps facilitate seperate development copies when you can't afford to
run a seperate development server.  Using C<dev_dirs> will have the
effect of temporarily appending the given C<dev_dir> to the component
root and data directory if the request is for a component in a
C<dev_dir>.

If no C<comp_root> parameter is passed to C<new()>, the component root
will be C<$ENV{DOCUMENT_ROOT}>.

=item * handle_request()

Handles the current request, reading input from C<$ENV{QUERY_STRING}>
or C<STDIN> and sending headers and component output to C<STDOUT>.
This method doesn't accept any parameters.  The initial component
will be the one specified in C<$ENV{PATH_INFO}>.

=item * handle_cgi()

Like C<handle_request()>, but the first (only) parameter is a
component path or component object.  This is useful within a
traditional CGI environment, in which you're essentially using Mason
as a templating language but not an application server.

C<handle_cgi()> will create a CGI query object, parse the query
parameters, and send the HTTP header and component output to STDOUT.
If you want to handle those parts yourself, see L<Using Mason from a
standalone script in HTML::Mason::Interp|HTML::Mason::Interp/"Using
Mason from a standalone script">.

=item * interp()

Returns the Mason Interpreter associated with this handler.  The
Interpreter lasts for the entire lifetime of the handler.

=back

=head2 C<$r> Methods

=over 4

=item * header_out()

This works much like the C<Apache> method of the same name.  When
passed the name of a header, returns the value of the given outgoing
header.  When passed a name and a value, sets the value of the header.
Setting the header to C<undef> will actually I<unset> the header,
removing it from the table of headers that will be sent to the client.

The headers are eventually passed to the C<CGI> module's C<header()>
method.

One header currently gets special treatment - if you set a C<Location>
header, you'll cause the C<CGI> module's C<redirect()> method to be
used instead of the C<header()> method.  This means that in order to
do a redirect, all you need to do is:

 $r->header_out(Location => 'http://redirect.to/here');


=item * content_type()

When passed an argument, sets the content type of the current request
to the value of the argument.  Use this method instead of setting a
C<Content-Type> header directly with C<header_out()>.  Like
C<header_out()>, setting the content type to C<undef> will remove any
content type set previously.

When called without arguments, returns the value set by a previous
call to C<content_type()>.  The behavior when C<content_type()> hasn't
already been set is undefined - currently it returns C<undef>.

If no content type is set during the request, the default MIME type
C<text/html> will be used.

=back

=head2 Added C<$m> methods

The C<$m> object provided in components has all the functionality of
the regular C<HTML::Mason::Request> object C<$m>, and the following:

=over 4

=item * cgi_object()

Returns the current C<CGI> request object.  This is handy for
processing cookies or perhaps even doing HTML generation (but is that
I<really> what you want to do?).  If you pass an argument to this
method, you can set the request object to the argument passed.  Use
this with care, as it may affect components called after the current
one (they may check the content length of the request, for example).

Note that the ApacheHandler class (for using Mason under mod_perl)
also provides a C<cgi_object()> method that does the same thing as
this one.  This makes it easier to write components that function
equally well under CGIHandler and ApacheHandler.

=back

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Admin|HTML::Mason::Admin>,
L<HTML::Mason::ApacheHandler|HTML::Mason::ApacheHandler>

=cut
