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
    todo_skip "Adding comments/correspondence is broken right now", 8;
    expect_send(q{create -t ticket set subject='new ticket'}, "Creating a ticket as just a subject...");
    expect_like(qr/Ticket \d+ created/, "Created the ticket");
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

# change a ticket's Owner
expect_send("edit ticket/$ticket_id set owner=root", 'Changing owner...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed owner');
expect_send("show ticket/$ticket_id -f owner", 'Verifying change...');
expect_like(qr/Owner: root/, 'Verified change');
# change a ticket's Requestor
expect_send("edit ticket/$ticket_id set requestors=foo\@example.com", 'Changing Requestor...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed Requestor');
expect_send("show ticket/$ticket_id -f requestors", 'Verifying change...');
expect_like(qr/Requestors: foo\@example.com/, 'Verified change');
# change a ticket's Cc
expect_send("edit ticket/$ticket_id set cc=bar\@example.com", 'Changing Cc...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed Cc');
expect_send("show ticket/$ticket_id -f cc", 'Verifying change...');
expect_like(qr/Cc: bar\@example.com/, 'Verified change');
# change a ticket's priority
expect_send("edit ticket/$ticket_id set priority=10", 'Changing priority...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed priority');
expect_send("show ticket/$ticket_id -f priority", 'Verifying change...');
expect_like(qr/Priority: 10/, 'Verified change');
# move a ticket to a different queue
expect_send("edit ticket/$ticket_id set queue=Foo", 'Changing queue...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed queue');
expect_send("show ticket/$ticket_id -f queue", 'Verifying change...');
expect_like(qr/Queue: Foo/, 'Verified change');
# cannot move ticket to a nonexistent queue
expect_send("edit ticket/$ticket_id set queue=nonexistent-$$", 'Changing to nonexistent queue...');
expect_like(qr/queue does not exist/i, 'Errored out');
expect_send("show ticket/$ticket_id -f queue", 'Verifying lack of change...');
expect_like(qr/Queue: Foo/, 'Verified lack of change');
# ...
# change a ticket's ...[other properties]...
# ...
# stall a ticket
expect_send("edit ticket/$ticket_id set status=stalled", 'Changing status to "stalled"...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed status');
expect_send("show ticket/$ticket_id -f status", 'Verifying change...');
expect_like(qr/Status: stalled/, 'Verified change');
# resolve a ticket
expect_send("edit ticket/$ticket_id set status=resolved", 'Changing status to "resolved"...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed status');
expect_send("show ticket/$ticket_id -f status", 'Verifying change...');
expect_like(qr/Status: resolved/, 'Verified change');
# try to set status to an illegal value
expect_send("edit ticket/$ticket_id set status=quux", 'Changing status to an illegal value...');
expect_like(qr/illegal value/i, 'Errored out');
expect_send("show ticket/$ticket_id -f status", 'Verifying lack of change...');
expect_like(qr/Status: resolved/, 'Verified change');

# }}}

# {{{ display

# show ticket list
expect_send("ls -s -t ticket -o +id \"Status='resolved'\"", 'Listing resolved tickets...');
expect_like(qr/$ticket_id: new ticket/, 'Found our ticket');
# show ticket list verbosely
expect_send("ls -l -t ticket -o +id \"Status='resolved'\"", 'Listing resolved tickets verbosely...');
expect_like(qr/id: ticket\/$ticket_id/, 'Found our ticket');
# show ticket
expect_send("show -t ticket $ticket_id", 'Showing our ticket...');
expect_like(qr/id: ticket\/$ticket_id/, 'Got our ticket');
# show ticket history
expect_send("show ticket/$ticket_id/history", 'Showing our ticket\'s history...');
expect_like(qr/Ticket created by root/, 'Got our history');
TODO: {
    todo_skip "Cannot show verbose ticket history right now", 2;
    # show ticket history verbosely
    expect_send("show -v ticket/$ticket_id/history", 'Showing our ticket\'s history verbosely...');
    expect_like(qr/Ticket created by root/, 'Got our history');
}
# get attachments from a ticket
expect_send("show ticket/$ticket_id/attachments", 'Showing ticket attachments...');
expect_like(qr/id: ticket\/$ticket_id\/attachments/, 'Got our ticket\'s attachments');
expect_like(qr/Attachments: \d+:\s*\(\S+ \/ \d+\w+\)/, 'Our ticket has an attachment');
expect_handle->before() =~ /Attachments: (\d+):\s*\((\S+)/;
my $attachment_id = $1;
my $attachment_type = $2;
ok($attachment_id, "Got attachment id=$attachment_id $attachment_type");
expect_send("show ticket/$ticket_id/attachments/$attachment_id", "Showing attachment $attachment_id...");
expect_like(qr/ContentType: $attachment_type/, 'Got the attachment');

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
