package RT::Interface::Web::Standalone;

use strict;
use base 'HTTP::Server::Simple::Mason';
use RT::Interface::Web::Handler;
use RT::Interface::Web;


sub new_handler {
   my $m;
   $m=  RT::Interface::Web::Handler->new(@RT::MasonParameters,
   # Override mason's default output method so 
   # we can change the binmode to our encoding if
   # we happen to be handed character data instead
   # of binary data.
   # 
   # Cloned from HTML::Mason::CGIHandler
    out_method => 
      sub {
            my $m = HTML::Mason::Request->instance;
            my $r = $m->cgi_request;
            # Send headers if they have not been sent by us or by user.
            # We use instance here because if we store $request we get a
            # circular reference and a big memory leak.
                unless ($m->{'http_header_sent'}) {
                       $r->send_http_header();
                }
            {
            if ($r->content_type =~ /charset=([\w-]+)$/ ) {
                my $enc = $1;
                binmode *STDOUT, ":encoding($enc)";
            }
            # We could perhaps install a new, faster out_method here that
            # wouldn't have to keep checking whether headers have been
            # sent and what the $r->method is.  That would require
            # additions to the Request interface, though.
             print STDOUT grep {defined} @_;
            }
        }
    );
        return ($m); 
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
