package RT::Interface::Web::Handler;

sub DefaultHandlerArgs  { (
    comp_root => [
        [ local    => $RT::MasonLocalComponentRoot ],
        [ standard => $RT::MasonComponentRoot ]
    ],
    default_escape_flags => 'h',
    data_dir             => "$RT::MasonDataDir",
    allow_globals        => [qw(%session)],
    autoflush            => 1
) };

# {{{ sub new 

=head2 new

  Constructs a web handler of the appropriate class.
  Takes options to pass to the constructor.

=cut

sub new {
    my $class = shift;
    $class->InitSessionDir;

    if ($MasonX::Apache2Handler::VERSION) {
        goto &NewApache2Handler;
    }
    elsif ($mod_perl::VERSION >= 1.9908) {
	require Apache::RequestUtil;
	no warnings 'redefine';
	my $sub = *Apache::request{CODE};
	*Apache::request = sub {
	    my $r;
	    eval { $r = $sub->('Apache'); };
	    # warn $@ if $@;
	    return $r;
	};
        goto &NewApacheHandler;
    }
    elsif ($CGI::MOD_PERL) {
        goto &NewApacheHandler;
    }
    else {
        goto &NewCGIHandler;
    }
}

sub InitSessionDir {
    # Activate the following if running httpd as root (the normal case).
    # Resets ownership of all files created by Mason at startup.
    # Note that mysql uses DB for sessions, so there's no need to do this.
    unless ( $RT::DatabaseType =~ /(mysql|Pg)/ ) {

        # Clean up our umask to protect session files
        umask(0077);

        if ($CGI::MOD_PERL) {
            chown( Apache->server->uid, Apache->server->gid,
                [$RT::MasonSessionDir] )
            if Apache->server->can('uid');
        }

        # Die if WebSessionDir doesn't exist or we can't write to it
        stat($RT::MasonSessionDir);
        die "Can't read and write $RT::MasonSessionDir"
        unless ( ( -d _ ) and ( -r _ ) and ( -w _ ) );
    }

}

# }}}

# {{{ sub NewApacheHandler 

=head2 NewApacheHandler

  Takes extra options to pass to HTML::Mason::ApacheHandler->new
  Returns a new Mason::ApacheHandler object

=cut

sub NewApacheHandler {
    require HTML::Mason::ApacheHandler;
    return NewHandler('HTML::Mason::ApacheHandler', args_method => "CGI", @_);
}

# }}}

# {{{ sub NewApache2Handler 

=head2 NewApache2Handler

  Takes extra options to pass to MasonX::Apache2Handler->new
  Returns a new MasonX::Apache2Handler object

=cut

sub NewApache2Handler {
    require MasonX::Apache2Handler;
    return NewHandler('MasonX::Apache2Handler', args_method => "CGI", @_);
}

# }}}

# {{{ sub NewCGIHandler 

=head2 NewCGIHandler

  Returns a new Mason::CGIHandler object

=cut

sub NewCGIHandler {
    require HTML::Mason::CGIHandler;
    return NewHandler('HTML::Mason::CGIHandler', @_);
}

sub NewHandler {
    my $class = shift;
    my $handler = $class->new(
        DefaultHandlerArgs(),
        @_
    );
  
    $handler->interp->set_escape( h => \&RT::Interface::Web::EscapeUTF8 );
    return($handler);
}

# }}}

1;
