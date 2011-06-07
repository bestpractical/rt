package RT::CustomField::Type;
use strict;
use warnings;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;
    return wantarray ? (1) : 1;
}

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');

    return $content
}

sub CanonicalizeForSearch {
    my ($self, $cf, $value, $op ) = @_;
    return $value;
}

sub CreateArgsFromWebArgs {
    my ($self, $cf, $web_args) = @_;

    for my $arg (keys %$web_args) {
        next if $arg =~ /^(?:Magic|Category)$/;

        if ( $arg eq 'Upload'  && $web_args->{$arg}) {
            return HTML::Mason::Commands::_UploadedFileArgs($web_args->{Upload});
        }

        my $type = $cf->Type;

        my @values = ();
        if ( ref $web_args->{$arg} eq 'ARRAY' ) {
            @values = @{ $web_args->{$arg} };
        } elsif ( $type =~ /text/i ) {
            @values = ( $web_args->{$arg} );
        } else {
            no warnings 'uninitialized';
            @values = split /\r*\n/, $web_args->{$arg};
        }
        @values = grep length, map {
            s/\r+\n/\n/g;
            s/^\s+//;
            s/\s+$//;
            $_;
        } grep defined, @values;

        return \@values;
    }
}

1;
