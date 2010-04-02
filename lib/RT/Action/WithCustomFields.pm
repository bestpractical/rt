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
        $self->$method( %$args );
    }
}

sub _setup_custom_fields {
    my $self = shift;
    my %args = @_;
    my $cfs = $args{cfs};

    my @cf_args;

    while ( my $cf = $cfs->next ) {
        my $cf_args = $self->_setup_custom_field($cf);
        push @cf_args, $cf_args;
    }

    return @cf_args;
}

sub _setup_custom_field {
    my $self = shift;
    my $cf   = shift;

    my $render_as = $cf->type_for_rendering;
    my $name      = 'cf_' . $cf->id;

    my %args = (
        name      => $name,
        label     => $cf->name,
        render_as => $render_as,
    );

    if ( $self->record ) {

        # so we can find out default value
        my $ocfvs = $self->record->custom_field_values( $cf->id );

        if ( $ocfvs->count ) {

            if ( $render_as eq 'Upload' ) {
                # TODO handle file type input
            }
            else {
                if ( $cf->max_values == 1 ) {
                    $args{default_value} = $ocfvs->first->content;
                }
                else {
                    if ( $cf->type eq 'Freeform' ) {
                        $args{default_value} = join "\n",
                          map { $_->content } @{ $ocfvs->items_array_ref };
                    }
                    else {
                        $args{default_value} =
                          [ map { $_->content } @{ $ocfvs->items_array_ref } ];
                    }
                }

            }
        }
    }


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

sub _update_custom_field_values {
    my $self = shift;

    my @args = grep { /^cf_\d+$/ } $self->argument_names;
    for my $arg (@args) {
        my $id;
        $id = $1 if $arg =~ /^cf_(\d+)$/;    # this always happens
        $self->_update_custom_field_value(
            field => $1,
            value => $self->argument_value($arg),
        );

    }
}

sub _update_custom_field_value {
    my $self  = shift;
    my %args  = @_;
    my $field = $args{field};
    my $value = $args{value};

    my $cf = RT::Model::CustomField->new;
    my ( $status, $msg ) = $cf->load($field);
    unless ( $status ) {
        Jifty->log->error( $msg );
        return;
    }

    my @values = ref $value eq 'ARRAY' ? @$value : $value;
    if ( $cf->type eq 'Freeform' ) {

        @values = map { s!^\s+!!; s!\s+$!!; $_ } grep { /\S/ } split "\n",
          join "\n",
          @values;
    }

    my $ocfvs = $self->record->custom_field_values($field);
    while ( my $v = $ocfvs->next ) {
        my ( $status, $msg ) = $self->record->delete_custom_field_value(
            field    => $field,
            value_id => $v->id,
        );
        Jifty->log->error( $msg ) unless $status;
    }

    for my $value (@values) {
        if ( UNIVERSAL::isa( $value, 'Jifty::Web::FileUpload' ) ) {
            $self->record->add_custom_field_value(
                field         => $field,
                value         => $value->filename,
                large_content => $value->content,
                content_type  => $value->content_type,
            );
        }
        else {
            $self->record->add_custom_field_value(
                field => $field,
                value => $value,
            );
        }
    }
}

1;

