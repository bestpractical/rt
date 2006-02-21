#!/usr/bin/perl -w

use strict;
use Test::More qw/no_plan/;
#use Test::Env;
#use Test::Expect;

use RT;
RT::LoadConfig();
RT::Init;

ok(1);

# {{{  test configuration options

# config directives:
#    (in $CWD/.rtrc)
#    - server <URL>          URL to RT server.
#    - user <username>       RT username.
#    - passwd <passwd>       RT user's password.
#    - query <RT Query>      Default RT Query for list action
#    - orderby <order>       Default RT order for list action
#
#    Blank and #-commented lines are ignored.

# environment variables
#    The following environment variables override any corresponding
#    values defined in configuration files:
#
#    - RTUSER
#    - RTPASSWD
#    - RTSERVER
#    - RTDEBUG       Numeric debug level. (Set to 3 for full logs.)
#    - RTCONFIG      Specifies a name other than ".rtrc" for the
#                    configuration file.
#    - RTQUERY       Default RT Query for rt list
#    - RTORDERBY     Default order for rt list


# }}}

# {{{ test ticket manipulation

# connect to server (?)
# create a ticket
# add a comment to ticket
# add correspondance to ticket (?)
# add attachments to a ticket
# change a ticket's owner
# change a ticket's watchers
# change a ticket's priority
# change a ticket's ...[other properties]...
# move a ticket to a different queue
# stall a ticket
# resolve a ticket

# }}}

# {{{ display

# show ticket list
# show ticket list verbosely
# show ticket history
# show ticket history verbosely
# get attachments from a ticket

# }}}

# {{{ test user manipulation

# creating users
# updating users

# }}}

# {{{ custom field manipulation

# creating custom fields (TODO)
# updating custom field values

# }}}

1;
