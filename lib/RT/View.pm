use warnings;
use strict;

package RT::View;
use Jifty::View::Declare -base;

require RT::View::Admin::Groups;
alias RT::View::Admin::Groups under 'admin/groups/';

require RT::View::Admin::Users;
alias RT::View::Admin::Users under 'admin/groups/';

1;
