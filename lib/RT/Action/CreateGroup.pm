use strict;
use warnings;

=head1 NAME

RT::Action::CreateGroup

=cut

package RT::Action::CreateGroup;
use base qw/RT::Action RT::Action::Record::Create/;

=head2 create_record

This uses L<RT::Model::Group/create_user_defined> for creating user-defined
groups.

=cut

sub create_record {
    my $self  = shift;
    my $group = $self->record;

    return $group->create_user_defined(@_);
}

1;

