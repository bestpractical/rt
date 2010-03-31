package RT::Action::CreateCustomField;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Create/;

sub record_class { 'RT::Model::CustomField' }

use constant report_detailed_messages => 1;

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;
    return 1;
}

1;
