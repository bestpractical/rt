package RT::Action::UpdateCustomField;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::CustomField' }

use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    my $self = shift;
    param 'link_value_to' => hints is _(
q{RT can make this custom field's values into hyperlinks to another service.
Fill in this field with a URL.
RT will replace <tt>__id__</tt> and <tt>__CustomField__</tt> with the record
id and custom field value, respectively}
    );
    param 'include_content_for_value' => hints is _(
q{RT can include content from another web service when showing this custom field.
Fill in this field with a URL.
RT will replace <tt>__id__</tt> and <tt>__CustomField__</tt> with the record id and custom field value, respectively
Some browsers may only load content from the same domain as your RT server.}
    );

};

sub arguments {
    my $self = shift;
    my $args = $self->SUPER::arguments;

    if ( $self->has_values_sources ) {
        $args->{values_class} = {
            render_as     => 'Select',
            default_value => defer {
                return $self->record->values_class;
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
                    if ( $class eq 'RT::Model::CustomFieldValueCollection' ) {
                        $res{'display'} = 'Provide list of values below';
                    }
                    else {
                        $res{'display'} ||= $class;
                    }
                    push @values, \%res;
                }
                return \@values;
            },
        };
    }
    else {
        $args->{values_class} = {
            render => 'hidden',
        };
    }
    return $args;
}

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;

    my @attrs = qw/link_value_to include_content_for_value/;
    push @attrs, 'values_class' if $self->has_values_sources;

    for my $attr (@attrs) {
        if ( $self->has_argument($attr) ) {
            my $method = "set_$attr";
            # for non select cfs, we supply an empty and hidden input
            # and we don't want to set_... for that.
            next if $attr eq 'values_class' && !$self->argument_value($attr);

            my ( $status, $msg ) =
              $self->record->$method( $self->argument_value($attr) );
            Jifty->log->error($msg) unless $status;
        }
    }
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
