package RT::Interface::Web::Standalone;

use strict;
use base 'HTTP::Server::Simple::Mason';
use RT::Interface::Web::Handler;
use RT::Interface::Web;

sub handler_class { "RT::Interface::Web::Handler" }

sub setup_escapes {
    my $self = shift;
    my $handler = shift;

    # Override HTTP::Server::Simple::Mason's version of this method to do
    # nothing.  (RT::Interface::Web::Handler does this already for us in
    # NewHandler.)
} 

sub default_mason_config {
    return @RT::MasonParameters;
} 

sub handle_request {

    my $self = shift;
    my $cgi = shift;

    Module::Refresh->refresh if $RT::DevelMode;

    $self->SUPER::handle_request($cgi);
    $RT::Logger->crit($@) if ($@);

    RT::Interface::Web::Handler->CleanupRequest();

}

1;
