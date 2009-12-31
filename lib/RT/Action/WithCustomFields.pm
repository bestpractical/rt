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

    my @cf_args;

    while ( my $cf = $cfs->next ) {
        my $cf_args = $self->setup_custom_field($cf);
        push @cf_args, $cf_args;
    }

    return @cf_args;
}

sub _setup_custom_field {
    my $self = shift;
    my $cf = shift;

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

    return \%args;
}

1;

