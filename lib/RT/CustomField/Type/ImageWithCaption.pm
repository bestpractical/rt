package RT::CustomField::Type::ImageWithCaption;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

sub CreateArgsFromWebArgs {
    my ($self, $cf, $web_args) = @_;

    return unless $web_args->{Upload};

    my $args = HTML::Mason::Commands::_UploadedFileArgs($web_args->{Upload});
    # override value over filename from upload, if caption is provided
    $args->{Value} = $web_args->{Value} if length $web_args->{Value};
    return $args;
}

sub UpdateArgsFromWebArgs {
    my ($self, $cf, $web_args) = @_;
    $self->CreateArgsFromWebArgs($cf, $web_args);
}

1;
