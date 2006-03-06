#!/usr/bin/perl -w

use strict;
use Test::Expect;
use Test::More qw/no_plan/;

use RT;
RT::LoadConfig();
RT::Init;

my $rt_tool_path = "$RT::BinPath/rt";

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
$ENV{'RTUSER'} = 'root';
#    - RTPASSWD
$ENV{'RTPASSWD'} = 'password';
#    - RTSERVER
$ENV{'RTSERVER'} = 'http://localhost:80/';
#    - RTDEBUG       Numeric debug level. (Set to 3 for full logs.)
$ENV{'RTDEBUG'} = '3';
#    - RTCONFIG      Specifies a name other than ".rtrc" for the
#                    configuration file.
#
#    - RTQUERY       Default RT Query for rt list
#    - RTORDERBY     Default order for rt list


# }}}

# {{{ test ticket manipulation

# create a ticket
expect_run(
    command => "$rt_tool_path shell",
    prompt => 'rt> ',
    quit => 'quit',
);
expect_send(q{create -t ticket set subject='new ticket' add cc=foo@example.com}, "Creating a ticket...");
expect_like(qr/Ticket \d+ created/, "Created the ticket");
expect_handle->before() =~ /Ticket (\d+) created/;
my $ticket_id = $1;
ok($ticket_id, "Got ticket id=$ticket_id");

# add a comment to ticket
TODO: {
    todo_skip "Adding comments/correspondence is broken right now", 6;
    expect_send("comment -m 'comment-$$' $ticket_id", "Adding a comment...");
    expect_like(qr/Comment added/, "Added the comment");
    ### should test to make sure it actually got added
    # add correspondance to ticket (?)
    expect_send("correspond -m 'correspond-$$' $ticket_id", "Adding correspondence...");
    expect_like(qr/Correspondence added/, "Added the correspondence");
    ### should test to make sure it actually got added
    # add attachments to a ticket
    expect_send("comment -m 'attach file' $rt_tool_path $ticket_id", "Adding an attachment");
    expect_like(qr/Comment added/, "Added the attachment");
    ### should test to make sure it actually got added
}

# change a ticket's owner
expect_send("edit ticket/$ticket_id set owner=root", 'Changing owner...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed owner');
expect_send("show ticket/$ticket_id -f owner", 'Verifying change...');
expect_like(qr/Owner: root/, 'Verified change');
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
