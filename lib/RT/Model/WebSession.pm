use strict;
use warnings;

package RT::Model::WebSession;
use base qw/RT::Record/;
use Jifty::DBI::Schema;
sub table {'sessions'}

use Jifty::DBI::Record schema {
    column a_session   => type is 'blob';
    column LastUpdated => type is 'datetime';
    column id          => type is 'varchar(32)';
};

# Your model-specific methods go here.

1;

