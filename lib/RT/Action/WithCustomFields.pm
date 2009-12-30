package RT::Action::WithCustomFields;
use strict;
use warnings;

sub _add_custom_fields {
    my $self = shift;
    my %args = @_;

    my $cfs    = $args{cfs};
    my $method = $args{method};

    my @args = $self->_setup_custom_fields( cfs => $cfs );

    for my $args ( @args ) {
        $self->$method( $args );
    }
}

sub _setup_custom_fields {
    my $self = shift;
    my %args = @_;
    my $cfs = $args{cfs};

    my @args;
    while ( my $cf = $cfs->next ) {
        my $render_as = $cf->type_for_rendering;
        my $name      = 'cf_' . $cf->id;

        my %args = (
            name      => $name,
            label     => $cf->name,
            render_as => $render_as,
        );

        if ( $render_as =~ /Select/i ) {
            $args{valid_values} = [
                {
                    collection   => $cf->values,
                    display_from => 'name',
                    value_from   => 'name',
                }
            ];
        }
        elsif ( $render_as =~ /Combobox/i ) {
            $args{available_values} = [
                {
                    collection   => $cf->values,
                    display_from => 'name',
                    value_from   => 'name',
                }
            ];
        }

        push @args, \%args;
    }
    return @args;
}

1;

