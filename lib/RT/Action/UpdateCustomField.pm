package RT::Action::UpdateCustomField;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::CustomField' }

use constant report_detailed_messages => 1;
use Scalar::Defer 'defer';

sub arguments {
    my $self = shift;
    my $args = $self->SUPER::arguments;

    if ( $self->has_values_sources ) {
        $args->{values_class} = {
            render_as     => 'Select',
            default_value => defer {
                $self->record->values_class;
            },
            available_values => defer {
                my @values;
                for my $class ( 'RT::Model::CustomFieldValueCollection',
                    @{ RT->config->get('custom_field_values_sources') } )
                {
                    next unless $class;
                    local $@;
                    eval "require $class";
                    if ($@) {
                        Jifty->log->fatal("Couldn't load class '$class': $@");
                        next;
                    }
                    my %res = ( value => $class );
                    $res{'display'} = $class->source_description
                      if $class->can('source_description');
                    $res{'display'} ||= $class;
                    push @values, \%res;
                }
                return \@values;
            },
        };
    }
    else {
        $args->{values_class} = {
            render_as => 'hidden',
        };
    }
    return $args;
}

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;
    return 1;
}

sub has_values_sources {
    my $self = shift;
    return
         $self->record->id
      && $self->record->is_selection_type
      && RT->config->get('custom_field_values_sources')
      && ( scalar( @{ RT->config->get('custom_field_values_sources') } ) > 0 );
}

1;
