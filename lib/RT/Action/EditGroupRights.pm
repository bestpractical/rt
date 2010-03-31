
use strict;
use warnings;

package RT::Action::EditGroupRights;
use base qw/RT::Action::EditRights/;
use Scalar::Defer;

sub arguments {
    my $self = shift;
    return {} unless $self->record;
    my $args = $self->SUPER::arguments( @_ );

    my @groups;

    {
        my $groups = RT::Model::GroupCollection->new;
        $groups->limit_to_system_internal_groups();
        while ( my $group = $groups->next ) {
            push @groups, $group;
        }
    }

    {
        my $groups = RT::Model::GroupCollection->new;
        $groups->limit_to_user_defined_groups();
        while ( my $group = $groups->next ) {
            push @groups, $group;
        }
    }

    {
        my $groups =
          RT::Model::GroupCollection->new;
        $groups->limit_to_roles( object => $self->record );
        while ( my $group = $groups->next ) {
            push @groups, $group;
        }
    }

    for my $group ( @groups ) {
        my $name = 'rights_' . $group->principal_id;
        $args->{$name} = {
            default_value    => defer {
                $self->default_value($group->principal_id) },
            available_values => defer { $self->available_values },
            render_as        => 'Checkboxes',
            multiple         => 1,
            label => $group->name || $group->type,
        };
    }
    return $args;
}

1;

