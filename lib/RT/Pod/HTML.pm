use strict;
use warnings;

package RT::Pod::HTML;
use base 'Pod::Simple::XHTML';

sub new {
    my $self = shift->SUPER::new(@_);
    $self->index(1);
    $self->anchor_items(1);
    return $self;
}

sub perldoc_url_prefix { "http://metacpan.org/module/" }

sub html_header { '' }
sub html_footer {
    my $self = shift;
    my $toc  = "../" x ($self->batch_mode_current_level - 1);
    return '<a href="./' . $toc . '">&larr; Back to index</a>';
}

sub start_Verbatim { $_[0]{'scratch'} = "<pre>" }
sub end_Verbatim   { $_[0]{'scratch'} .= "</pre>"; $_[0]->emit; }

sub _end_head {
    my $self = shift;
    $self->{scratch} = '<a href="#___top">' . $self->{scratch} . '</a>';
    return $self->SUPER::_end_head(@_);
}

sub resolve_pod_page_link {
    my $self = shift;
    my ($name, $section) = @_;

    # Only try to resolve local links if we're in batch mode and are linking
    # outside the current document.
    return $self->SUPER::resolve_pod_page_link(@_)
        unless $self->batch_mode and $name;

    $section = defined $section
        ? '#' . $self->idify($section, 1)
        : '';

    my $local;
    if ($name =~ /^RT::/) {
        $local = join "/",
                  map { $self->encode_entities($_) }
                split /::/, $name;
    }
    elsif ($name =~ /^rt-/) {
        $local = $self->encode_entities($name);
    }

    if ($local) {
        # Resolve links correctly by going up
        my $depth = $self->batch_mode_current_level - 1;
        return join "/",
                    ($depth ? ".." x $depth : ()),
                    "$local.html$section";
    } else {
        return $self->SUPER::resolve_pod_page_link(@_)
    }
}

1;
