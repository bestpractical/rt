package RT::Interface::Web::Mason::HandlerMixin;

use strict;
use warnings;

use Exporter ();
our @ISA = qw(Exporter);

our (@EXPORT_OK, @EXPORT);
@EXPORT_OK = @EXPORT = qw(image_file_request);

sub image_file_request {
    my ($self, $path) = @_;

    return unless $path =~ /\.(gif|png|jpe?g)$/i;
    my $type = "image/$1";
    $type =~ s/jpg/jpeg/gi;

    my $file;
    for my $comp_root (map { $_->[1] } @{ $self->interp->comp_root }) {
        my $tmp = File::Spec->catfile($comp_root, $path);
        next unless -f $tmp;
        $file = $tmp;
        last;
    }
    return unless $file;

    return ($file, $type);
}

1;
