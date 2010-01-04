package RT::Action::CreateCustomField;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Create/;

sub record_class { 'RT::Model::CustomField' }

use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
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

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;

    my @attrs = qw/link_value_to include_content_for_value/;

    for my $attr (@attrs) {
        if ( $self->has_argument($attr) ) {
            my $method = "set_$attr";
            my ( $status, $msg ) =
              $self->record->$method( $self->argument_value($attr) );
            Jifty->log->error($msg) unless $status;
        }
    }
    return 1;
}

1;
