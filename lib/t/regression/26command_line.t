#!/usr/bin/perl -w

use strict;
use Test::Expect;
#use Test::More qw/no_plan/;
use Test::More tests => 100;

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
$RT::Logger->debug("Connecting to server at $RT::WebBaseURL...");
$ENV{'RTSERVER'} = $RT::WebBaseURL;
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
    local $TODO = "Adding comments/correspondence is broken right now";
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
    local $TODO = "Cannot show verbose ticket history right now";
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
expect_send("create -t user set Name='NewUser$$' EmailAddress='fbar$$\@example.com'", 'Creating a user...');
expect_like(qr/User \d+ created/, 'Created the user');
expect_handle->before() =~ /User (\d+) created/;
my $user_id = $1;
ok($user_id, "Got user id=$user_id");
# updating users
expect_send("edit user/$user_id set Name='EditedUser$$'", 'Editing the user');
expect_like(qr/User $user_id updated/, 'Edited the user');
expect_send("show user/$user_id", 'Showing the user...');
expect_like(qr/id: user\/$user_id/, 'Saw the user');
expect_like(qr/Name: EditedUser$$/, 'Saw the modification');
TODO: { 
    todo_skip "Listing non-ticket items doesn't work", 2;
    expect_send("list -t user 'id > 0'", 'Listing the users...');
    expect_like(qr/$user_id: EditedUser$$/, 'Found the user');
}

# }}}

# {{{ test group manipulation

TODO: {
todo_skip "Group manipulation doesn't work right now", 8;
# creating groups
expect_send("create -t group set Name='NewGroup$$'", 'Creating a group...');
expect_like(qr/Group \d+ created/, 'Created the group');
expect_handle->before() =~ /Group (\d+) created/;
my $group_id = $1;
ok($group_id, "Got group id=$group_id");
# updating groups
expect_send("edit group/$group_id set Name='EditedGroup$$'", 'Editing the group');
expect_like(qr/Group $group_id updated/, 'Edited the group');
expect_send("show group/$group_id", 'Showing the group...');
expect_like(qr/id: group\/$group_id/, 'Saw the group');
expect_like(qr/Name: EditedGroup$$/, 'Saw the modification');
TODO: { 
    local $TODO = "Listing non-ticket items doesn't work";
    expect_send("list -t group 'id > 0'", 'Listing the groups...');
    expect_like(qr/$group_id: EditedGroup$$/, 'Found the group');
}
}

# }}}

# {{{ test queue manipulation

# creating queues
expect_send("create -t queue set Name='NewQueue$$'", 'Creating a queue...');
expect_like(qr/Queue \d+ created/, 'Created the queue');
expect_handle->before() =~ /Queue (\d+) created/;
my $queue_id = $1;
ok($queue_id, "Got queue id=$queue_id");
# updating users
expect_send("edit queue/$queue_id set Name='EditedQueue$$'", 'Editing the queue');
expect_like(qr/Queue $queue_id updated/, 'Edited the queue');
expect_send("show queue/$queue_id", 'Showing the queue...');
expect_like(qr/id: queue\/$queue_id/, 'Saw the queue');
expect_like(qr/Name: EditedQueue$$/, 'Saw the modification');
TODO: { 
    todo_skip "Listing non-ticket items doesn't work", 2;
    expect_send("list -t queue 'id > 0'", 'Listing the queues...');
    expect_like(qr/$queue_id: EditedQueue$$/, 'Found the queue');
}

# }}}

TODO: {
todo_skip "Custom field manipulation not yet implemented", 8;
# {{{ test custom field manipulation

# creating custom fields
expect_send("create -t custom_field set Name='NewCF$$'", 'Creating a custom field...');
expect_like(qr/Custom Field \d+ created/, 'Created the custom field');
expect_handle->before() =~ /Custom Field (\d+) created/;
my $cf_id = $1;
ok($cf_id, "Got custom field id=$cf_id");
# updating custom fields
expect_send("edit cf/$cf_id set Name='EditedCF$$'", 'Editing the custom field');
expect_like(qr/Custom field $cf_id updated/, 'Edited the custom field');
expect_send("show cf/$cf_id", 'Showing the queue...');
expect_like(qr/id: custom_field\/$cf_id/, 'Saw the custom field');
expect_like(qr/Name: EditedCF$$/, 'Saw the modification');
TODO: { 
    todo_skip "Listing non-ticket items doesn't work", 2;
    expect_send("list -t custom_field 'id > 0'", 'Listing the CFs...');
    expect_like(qr/$cf_id: EditedCF$$/, 'Found the custom field');
}
}

# }}}

1;
