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
    my %args = @_;
    (defined $args{$_} or delete $args{$_}) for keys %args;
    %args = ((CustomField => '0',
              Name => '',
              Description => '',
              SortOrder => '0',
              Category => ''), %args);

    my ($id, $msg) = $self->SUPER::Create(
        map {$_ => $args{$_}} qw(CustomField Name Description SortOrder)
    );
    if ($id and length $args{Category}) {
        # $self would be loaded at this stage
        $self->SetCategory($args{Category});
    }
    return ($id, $msg);
}

sub Category {
    my $self = shift;
    return '';
}

sub SetCategory {
    my $self = shift;
    my $category = shift;
    return (0, '');
}

sub ValidateName { 1 };

1;
