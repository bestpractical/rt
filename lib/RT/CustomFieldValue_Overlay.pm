use warnings;
use strict;

package RT::CustomFieldValue;

no warnings qw/redefine/;


=head2 ValidateName

Override the default ValidateName method that stops custom field values
from being integers.

=cut

sub Create {
    my $self = shift;
    my %args = (
        CustomField => 0,
        Name        => '',
        Description => '',
        SortOrder   => 0,
        Category    => '',
        @_,
    );

    my ($id, $msg) = $self->SUPER::Create(
        map { $_ => $args{$_} } qw(CustomField Name Description SortOrder)
    );

    if ( $id && length $args{Category} ) {
        # $self would be loaded at this stage
        my ($status, $msg) = $self->SetCategory( $args{Category} );
        unless ( $status ) {
            $RT::Logger->error("Couldn't set category: $msg");
        }
    }

    return ($id, $msg);
}

sub Category {
    my $self = shift;
    my $attr = $self->FirstAttribute('Category') or return undef;
    return $attr->Content;
}

sub SetCategory {
    my $self = shift;
    my $category = shift;
    if ( defined $category && length $category ) {
        return $self->SetAttribute(
            Name    => 'Category',
            Content => $category,
        );
    }
    else {
        my ($status, $msg) = $self->DeleteAttribute( 'Category' );
        unless ( $status ) {
            $RT::Logger->warning("Couldn't delete atribute: $msg");
        }
        # return true even if there was no category
        return (1, $self->loc('Category unset'));
    }
}

sub ValidateName { 1 };

1;
