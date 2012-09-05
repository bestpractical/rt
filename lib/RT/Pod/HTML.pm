use strict;
use warnings;

package RT::Pod::HTML;
use base 'Pod::Simple::XHTML';

sub new {
    my $self = shift->SUPER::new(@_);
    $self->index(1);
    return $self;
}

sub perldoc_url_prefix { "http://metacpan.org/module/" }

sub html_header { '' }
sub html_footer { '' }

sub start_Verbatim { $_[0]{'scratch'} = "<pre>" }
sub end_Verbatim   { $_[0]{'scratch'} .= "</pre>"; $_[0]->emit; }

sub _end_head {
    my $self = shift;
    $self->{scratch} = '<a href="#___top">' . $self->{scratch} . '</a>';
    return $self->SUPER::_end_head(@_);
}

1;
