package RT::Action::BulkUpdateLinks;
use Jifty::Action::Record::Bulk;
use base 'Jifty::Action::Record::Bulk';

__PACKAGE__->actions([]);
__PACKAGE__->add_action('RT::Action::DeleteLink' => { trigger => 'delete', final => 1 });
__PACKAGE__->add_action('RT::Action::UpdateLink');

use Jifty::Param::Schema;
use Jifty::Action schema {

param delete => label is 'Delete',
    sort_order is -1,
    render as 'checkbox';

};

1;
