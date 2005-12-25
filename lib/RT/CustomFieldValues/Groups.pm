package RT::CustomFieldValues::Groups;

use strict;
use warnings;

use base qw(RT::CustomFieldValues::External);

sub SourceDescription {
    return 'RT user defined groups';
}

sub ExternalValues {
    my $self = shift;

    my @res;
    my $i = 0;
    my $groups = RT::Groups->new( $self->CurrentUser );
    $groups->LimitToUserDefinedGroups;
    $groups->OrderByCols( { FIELD => 'Name' } );
    while( my $group = $groups->Next ) {
        push @res, {
            name => $group->Name,
            sortorder => $i++,
        };
    }
    return \@res;
}


1;
