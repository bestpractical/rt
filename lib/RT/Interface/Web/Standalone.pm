package RT::Interface::Web::Standalone;

use strict;
use base 'HTTP::Server::Simple::Mason';
use RT::Interface::Web::Handler;
use RT::Interface::Web;

sub new_handler {
    RT::Interface::Web::Handler->new(@RT::MasonParameters);
}

sub handle_request {

    my $self = shift;
    my $cgi = shift;

    $self->SUPER::handle_request($cgi);
    $RT::Logger->crit($@) if ($@);

    RT::Interface::Web::Handler->CleanupRequest();

}

1;
