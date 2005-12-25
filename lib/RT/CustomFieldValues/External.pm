package RT::CustomFieldValues::External;

use strict;
use warnings;

use base qw(RT::CustomFieldValues);

sub _Init {
    my $self = shift;
    $self->Table( 'Groups' );
    return ( $self->SUPER::_Init(@_) );
}

sub Limit {
    my $self = shift;
    my %args = (@_);
    $self->{'__external_limits'} ||= [];
    push @{ $self->{'__external_limits'} }, \%args;
    return $self->SUPER::Limit( %args );
}

sub _DoSearch {
    my $self = shift;

    delete $self->{'items'};

    my %defaults = (
            id => 1,
            name => '',
            customfield => $self->{'__external_custom_field'},
            sortorder => 0,
            description => '',
            creator => $RT::SystemUser->id,
            created => undef,
            lastupdatedby => $RT::SystemUser->id,
            lastupdated => undef,
    );

    my $i = 0;

    my $groups = RT::Groups->new( $self->CurrentUser );
    $groups->LimitToUserDefinedGroups;
    $groups->OrderByCols( { FIELD => 'Name' } );
    foreach( @{ $self->ExternalValues } ) {
        my $value = $self->NewItem;
        $value->LoadFromHash( { %defaults, %$_ } );
        $self->AddRecord( $value );
    }
    $self->{'must_redo_search'} = 0;
    return $self->_RecordCount;
}

sub _DoCount {
    my $self = shift;

    my $count;
    $count = $self->_DoSearch if $self->{'must_redo_search'};
    $count = $self->_RecordCount unless defined $count;

    return $self->{'count_all'} = $self->{'raw_rows'} = $count;
}

sub LimitToCustomField {
    my $self = shift;
    $self->{'__external_custom_field'} = $_[0];
    return $self->SUPER::LimitToCustomField( @_ );
}

1;
