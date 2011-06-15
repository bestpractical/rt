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

sub SearchBuilderUIArguments {
    my ($self, $cf) = @_;
    my %line;

    if ($cf->Type =~ /^Date(Time)?$/ ) {
        $line{'Op'} = {
            Type => 'component',
            Path => '/Elements/SelectDateRelation',
            Arguments => {},
        };
    }
    elsif ($cf->Type =~ /^IPAddress(Range)?$/ ) {
        $line{'Op'} = {
            Type => 'component',
            Path => '/Elements/SelectIPRelation',
            Arguments => {},
        };
    } else {
        $line{'Op'} = {
            Type => 'component',
            Path => '/Elements/SelectCustomFieldOperator',
            Arguments => { True => $cf->loc("is"),
                           False => $cf->loc("isn't"),
                           TrueVal=> '=',
                           FalseVal => '!=',
                         },
        };
    }

    # Value
    if ($cf->Type =~ /^Date(Time)?$/) {
        my $is_datetime = $1 ? 1 : 0;
        $line{'Value'} = {
            Type => 'component',
            Path => '/Elements/SelectDate',
            Arguments => { $is_datetime ? (ShowTime => 1) : (ShowTime => 0), },
        };
    } else {
        $line{'Value'} = {
            Type => 'component',
            Path => '/Elements/SelectCustomFieldValue',
            Arguments => { CustomField => $cf },
        };
    }

    return %line;
}

1;
