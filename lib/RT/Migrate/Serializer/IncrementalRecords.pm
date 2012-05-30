package RT::Migrate::Serializer::IncrementalRecords;
use base qw/RT::SearchBuilder/;

use strict;
use warnings;

sub Table {'IncrementalRecords'}

sub NewItem {
    my $self = shift;
    return(RT::Migrate::Serializer::IncrementalRecord->new($self->CurrentUser));
}

RT::Base->_ImportOverlays();

1;
