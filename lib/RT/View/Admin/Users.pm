use warnings;
use strict;

package RT::View::Admin::Users;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';

__PACKAGE__->use_mason_wrapper;


sub per_page           {50}
sub object_type        {'User'}
sub display_columns { qw(id name email) }

1;
