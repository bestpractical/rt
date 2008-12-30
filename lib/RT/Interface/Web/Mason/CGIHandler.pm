package RT::Interface::Web::Mason::CGIHandler;

use strict;
use warnings;

# use base fails here (see rt3.fsck.com#12555)
require HTML::Mason::CGIHandler;
our @ISA = qw(HTML::Mason::CGIHandler);
use RT::Interface::Web::Mason::HandlerMixin;

sub handle_cgi_object {
    my ($self, $cgi) = @_;

    if (my ($file, $type) = $self->image_file_request($cgi->path_info)) {
        # Mason will pick the component off of the pathinfo 
        # and we need to trick it into taking arguments since other
        # options like handle_comp don't take args and exec needs
        # us to set up $m and $r by hand
        $cgi->param(-name => 'File', -value => $file);
        $cgi->param(-name => 'Type', -value => $type);
        $cgi->path_info('/NoAuth/SendStaticFile');
        $self->SUPER::handle_cgi_object($cgi);

        return;
    }

    $self->SUPER::handle_cgi_object($cgi);
}

1;
