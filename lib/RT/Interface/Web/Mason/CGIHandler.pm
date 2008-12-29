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
        print $cgi->header(-type => $type,
                           -Content_length => (-s $file) );
        open my $fh, "<$file" or die "Can't open $file: $!";
        binmode($fh);
        local $/ = \16384;
        print $_ while <$fh>;
        close $fh;
        return;
    }

    $self->SUPER::handle_cgi_object($cgi);
}

1;
