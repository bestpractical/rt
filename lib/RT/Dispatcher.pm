
use warnings;
use strict;
package RT::Dispatcher;

use Jifty::Dispatcher -base;

use RT;
RT->load_config;
use RT::Interface::Web;
use RT::Interface::Web::Handler;

before qr/.*/ => run {
RT::InitSystemObjects();

};

after qr/.*/ => run {
    RT::Interface::Web::Handler::CleanupRequest()
};

1;
