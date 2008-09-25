package RT::Interface::Web::Mason::ApacheHandler;

use strict;
use warnings;

use base qw(HTML::Mason::ApacheHandler);
use RT::Interface::Web::Mason::HandlerMixin;

sub handle_request {
    my ($self, $r) = @_;

    if (my ($file, $type) = $self->image_file_request($r->uri)) {
        # is there a better way, like changing $r->filename and letting Apache
        # send the file?
        $r->content_type($type);
        open my $fh, "<$file" or die "Can't open $file: $!";
        binmode($fh);
        local $/ = \16384;
        $r->print($_) while <$fh>;
        return;
    }

    $self->SUPER::handle_request($r);
}

1;
