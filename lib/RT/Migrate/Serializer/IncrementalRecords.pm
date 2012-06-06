package RT::Migrate::Serializer::IncrementalRecords;
use base qw/RT::SearchBuilder/;

use strict;
use warnings;

sub _Init {
    my $self = shift;
    $self->{'table'} = 'IncrementalRecords';
    $self->{'primary_key'} = 'id';
    return ( $self->SUPER::_Init(@_) );
}

sub Table {'IncrementalRecords'}

sub NewItem {
    my $self = shift;
    return(RT::Migrate::Serializer::IncrementalRecord->new($self->CurrentUser));
}

1;
