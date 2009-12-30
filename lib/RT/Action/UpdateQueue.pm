package RT::Action::UpdateQueue;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::Queue' }

use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param sign =>
        render as 'Checkbox';
    param encrypt =>
        render as 'Checkbox',
};

=head2 take_action

=cut

1;
