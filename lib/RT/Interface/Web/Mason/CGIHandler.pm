package RT::Interface::Web::Mason::CGIHandler;

use strict;
use warnings;

use base qw(HTML::Mason::CGIHandler);
use RT::Interface::Web::Mason::HandlerMixin;

sub handle_cgi_object {
    my ($self, $cgi) = @_;

    if (my ($file, $type) = $self->image_file_request($cgi->path_info)) {
        print "HTTP/1.0 200 OK\x0d\x0a";
        print "Content-Type: $type\x0d\x0a";
        print "Content-Length: " . (-s $file) . "\x0d\x0a\x0d\x0a";
        open my $fh, "<$file" or die "Can't open $file: $!";
        binmode($fh);
        {
            local $/ = \16384;
            print $_ while <$fh>;
        }
        close $fh;
        return;
    }

    $self->SUPER::handle_cgi_object($cgi);
}

1;
