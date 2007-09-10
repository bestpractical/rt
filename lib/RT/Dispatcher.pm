
use warnings;
use strict;
package RT::Dispatcher;

use Jifty::Dispatcher -base;

use RT;
RT->load_config;

1;
