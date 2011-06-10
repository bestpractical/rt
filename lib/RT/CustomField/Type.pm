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

    if ( !(defined $content && length $content) && $ocfv->ContentType && $ocfv->ContentType eq 'text/plain' ) {
        return $ocfv->LargeContent;
    } else {
        return $content;
    }
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

        return [$self->ValuesFromWeb($cf, $web_args->{$arg})];
    }
}


=head2 ValuesFromWeb C<$args>

Parse the args passed in from web

=cut

sub ValuesFromWeb {
    my ($self, $cf, $args) = @_;

    my $type = $cf->Type || '';

    my @values = ();
    if ( ref $args eq 'ARRAY' ) {
        @values = @$args;
    } elsif ( $type =~ /text/i ) {    # Both Text and Wikitext
        @values = $args;
    } else {
        @values = split /\r*\n/, $args if defined $args;
    }
    return grep length, map {
        s/\r+\n/\n/g;
        s/^\s+//;
        s/\s+$//;
        $_;
    } grep defined, @values;
}


sub Limit {
    return;
}

1;
