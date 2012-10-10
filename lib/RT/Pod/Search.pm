use strict;
use warnings;

package RT::Pod::Search;
use base 'Pod::Simple::Search';

sub new {
    my $self = shift->SUPER::new(@_);
       $self->laborious(1)              # Find scripts too
            ->limit_re(qr/(?<!\.in)$/)  # Filter out .in files
            ->inc(0);                   # Don't look in @INC
    return $self;
}

1;
