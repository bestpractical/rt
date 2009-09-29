package RT::Action::CustomFieldBased;
use strict;
use warnings;
use base 'Jifty::Action';

sub _add_custom_fields {
    my $self = shift;
    my %args = @_;

    my $cfs    = $args{cfs};
    my $method = $args{method};

    while (my $cf = $cfs->next) {
        my $render_as = $cf->type_for_rendering;
        my %args = (
            name => $cf->name,
            render_as => $render_as,
        );

        if ($render_as =~ /Select/i) {
            $args{valid_values} = [ {
                collection   => $cf->values,
                display_from => 'name',
                value_from   => 'name',
            } ];
        }
        elsif ($render_as =~ /Combobox/i) {
            $args{available_values} = [ {
                collection   => $cf->values,
                display_from => 'name',
                value_from   => 'name',
            } ];
        }

        $self->$method(
            %args,
        );
    }
}

1;

