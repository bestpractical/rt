# ABERDEEN BRANCH SPECIFIC!

package RT::Template;

use strict;
use warnings;
no warnings 'once';
no warnings 'redefine';

BEGIN {
    *RT::Template::OldParse = \&RT::Template::Parse;
}


sub Parse {
    my $self = shift;
    my ($rv, $msg);

    if ($self->Content =~ m{^Content-Type:\s+text/html\b}im) {
        local $RT::Transaction::PreferredContentType = 'text/html';
        ($rv, $msg) = $self->OldParse(@_);
    }
    else {
        ($rv, $msg) = $self->OldParse(@_);
    }

    # We only HTMLify things if the template includes at least one Transaction->Content call.
    return ($rv, $msg) unless $rv and $self->Content =~ /->\s*Content\b/;

    my $orig_entity = $self->MIMEObj;
    my $mime_type   = $self->MIMEObj->mime_type;

    if (!$mime_type or $mime_type eq 'text/plain') {
        $self->_UpgradeToHTML(@_);
    }
    elsif ($mime_type eq 'text/html') {
        $self->_DowngradeFromHTML(@_);
    }

    return ($rv, $msg);
}

sub _DowngradeFromHTML {
    my $self = shift;
    my $orig_entity = $self->MIMEObj;

    local $RT::Transaction::PreferredContentType = 'text/plain';

    my ($rv, $msg) = $self->OldParse(@_);
    if (!$rv) {
        $self->{MIMEObj} = $orig_entity;
        return;
    }

    $orig_entity->head->mime_attr( "Content-Type" => 'text/html' );
    $orig_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );
    $orig_entity->make_multipart('alternative', Force => 1);

    my $new_entity = $self->{MIMEObj};
    $new_entity->head->mime_attr( "Content-Type" => 'text/plain' );
    $new_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );

    require HTML::FormatText;
    require HTML::TreeBuilder;
    $new_entity->bodyhandle(MIME::Body::InCore->new(\(scalar(HTML::FormatText->new(
        leftmargin  => 0,
        rightmargin => 78,
    )->format(
        HTML::TreeBuilder->new_from_content( $new_entity->bodyhandle->as_string )
    )))));

    $orig_entity->add_part($new_entity, 0); # plain comes before html
    $self->{MIMEObj} = $orig_entity;

    return ($rv, $msg);
}

sub _UpgradeToHTML {
    my $self = shift;
    my $orig_entity = $self->MIMEObj;

    local $RT::Transaction::PreferredContentType = 'text/html';

    require Text::Template;
    my $old_compile = \&Text::Template::compile;
    local *Text::Template::compile = sub {
        $old_compile->(@_) or return undef;
        
        my $self = shift;
        my @new_content;
        my $seen_header;
        foreach my $chunk (@{$self->{SOURCE}}) {
            if ($chunk->[0] eq 'TEXT') {
                my $new_text = $chunk->[1];
                my $header_text = '';
                if (!$seen_header) {
                    # We don't HTMLify anything within the header.
                    if ($new_text =~ /\n\n/) {
                        $seen_header = 1;

                        # Preserve the header text but upgrade the body text
                        ($header_text, $new_text) = split(/\n\n/, $new_text, 2);
                        $header_text .= "\n\n";
                    }
                    else {
                        push @new_content, $chunk;
                        next;
                    }
                }
                $new_text =~ s/&/&#38;/g;
                $new_text =~ s/</&lt;/g;
                $new_text =~ s/>/&gt;/g;
                $new_text =~ s/\n/\n<br \/>/g;
                push @new_content, [$chunk->[0], $header_text.$new_text, $chunk->[2]];
            }
            else {
                push @new_content, $chunk;
            }
        }
        $self->{SOURCE} = \@new_content;
    };

    my ($rv, $msg) = $self->OldParse(@_);
    if (!$rv) {
        $self->{MIMEObj} = $orig_entity;
        return;
    }

    $orig_entity->head->mime_attr( "Content-Type" => 'text/plain' );
    $orig_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );
    $orig_entity->make_multipart('alternative', Force => 1);

    my $new_entity = $self->{MIMEObj};
    $new_entity->head->mime_attr( "Content-Type" => 'text/html' );
    $new_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );

    $orig_entity->add_part($new_entity);
    $self->{MIMEObj} = $orig_entity;

    return ($rv, $msg);
}

1;
