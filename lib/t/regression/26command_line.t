#!/usr/bin/perl -w

use strict;
use Test::Expect;
#use Test::More qw/no_plan/;
use Test::More tests => 218;

use RT;
RT::LoadConfig();
RT::Init;

use RT::User;
use RT::Queue;

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
$ENV{'RTDEBUG'} = '1';
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
expect_send(q{create -t ticket set subject='new ticket'}, "Creating a ticket as just a subject...");
expect_like(qr/Ticket \d+ created/, "Created the ticket");

# make sure we can request things as 'rt foo'
expect_send(q{rt create -t ticket set subject='rt ticket'}, "Creating a ticket with 'rt create'...");
expect_like(qr/Ticket \d+ created/, "Created the ticket");

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


# Set up a custom field for editing tests
my $cf = RT::CustomField->new($RT::SystemUser);
my ($val,$msg) = $cf->Create(Name => 'MyCF'.$$, Type => 'FreeformSingle', Queue => $queue_id);
ok($val,$msg);

my $othercf = RT::CustomField->new($RT::SystemUser);
($val,$msg) = $othercf->Create(Name => 'My CF'.$$, Type => 'FreeformSingle', Queue => $queue_id);
ok($val,$msg);



# add a comment to ticket
    expect_send("comment -m 'comment-$$' $ticket_id", "Adding a comment...");
    expect_like(qr/Message recorded/, "Added the comment");
    ### should test to make sure it actually got added
    # add correspondance to ticket (?)
    expect_send("correspond -m 'correspond-$$' $ticket_id", "Adding correspondence...");
    expect_like(qr/Message recorded/, "Added the correspondence");
    ### should test to make sure it actually got added

    # add attachments to a ticket
    # text attachment
    check_attachment("$RT::BasePath/lib/t/data/lorem-ipsum");
    # binary attachment
    check_attachment($RT::MasonComponentRoot.'/NoAuth/images/bplogo.gif');

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
expect_send("edit ticket/$ticket_id set queue=EditedQueue$$", 'Changing queue...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed queue');
expect_send("show ticket/$ticket_id -f queue", 'Verifying change...');
expect_like(qr/Queue: EditedQueue$$/, 'Verified change');
# cannot move ticket to a nonexistent queue
expect_send("edit ticket/$ticket_id set queue=nonexistent-$$", 'Changing to nonexistent queue...');
expect_like(qr/queue does not exist/i, 'Errored out');
expect_send("show ticket/$ticket_id -f queue", 'Verifying lack of change...');
expect_like(qr/Queue: EditedQueue$$/, 'Verified lack of change');

# Test reading and setting custom fields without spaces
expect_send("show ticket/$ticket_id -f CF-myCF$$", 'Checking initial value');
expect_like(qr/CF-myCF$$:/i, 'Verified initial empty value');
expect_send("edit ticket/$ticket_id set 'CF-myCF$$=VALUE' ", 'Changing CF...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed cf');
expect_send("show ticket/$ticket_id -f CF-myCF$$", 'Checking new value');
expect_like(qr/CF-myCF$$: VALUE/i, 'Verified change');
# Test reading and setting custom fields with spaces
expect_send("show ticket/$ticket_id -f 'CF-my CF$$'", 'Checking initial value');
expect_like(qr/my CF$$:/i, 'Verified change');
expect_send("edit ticket/$ticket_id set 'CF-my CF$$=VALUE' ", 'Changing CF...');
expect_like(qr/Ticket $ticket_id updated/, 'Changed cf');
expect_send("show ticket/$ticket_id -f 'CF-my CF$$'", 'Checking new value');
expect_like(qr/my CF$$: VALUE/i, 'Verified change');
expect_send("ls 'id = $ticket_id' -f 'CF-my CF$$'", 'Checking new value');
expect_like(qr/my CF$$: VALUE/i, 'Verified change');

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

# {{{ test merging tickets
expect_send("create -t ticket set subject='CLIMergeTest1-$$'", 'Creating first ticket to merge...');
expect_like(qr/Ticket \d+ created/, 'Created first ticket');
expect_handle->before() =~ /Ticket (\d+) created/;
my $merge_ticket_A = $1;
ok($merge_ticket_A, "Got first ticket to merge id=$merge_ticket_A");
expect_send("create -t ticket set subject='CLIMergeTest2-$$'", 'Creating second ticket to merge...');
expect_like(qr/Ticket \d+ created/, 'Created second ticket');
expect_handle->before() =~ /Ticket (\d+) created/;
my $merge_ticket_B = $1;
ok($merge_ticket_B, "Got second ticket to merge id=$merge_ticket_B");
expect_send("merge $merge_ticket_B $merge_ticket_A", 'Merging the tickets...');
expect_like(qr/Merge completed/, 'Merged the tickets');
expect_send("show ticket/$merge_ticket_A/history", 'Checking merge on first ticket');
expect_like(qr/Merged into ticket #$merge_ticket_A by root/, 'Merge recorded in first ticket');
expect_send("show ticket/$merge_ticket_B/history", 'Checking merge on second ticket');
expect_like(qr/Merged into ticket #$merge_ticket_A by root/, 'Merge recorded in second ticket');
# }}}

# {{{ test taking/stealing tickets
{
    # create a user; give them privileges to take and steal
    ### TODO: implement 'grant' in the CLI tool; use that here instead.
    ###       this breaks the abstraction barrier, like, a lot.
    my $steal_user = RT::User->new($RT::SystemUser);
    my ($steal_user_id, $msg) = $steal_user->Create( Name => "fooser$$",
                                          EmailAddress => "fooser$$\@localhost",
                                          Privileged => 1,
                                          Password => 'foobar',
                                        );
    ok($steal_user_id, "Created the user? $msg");
    my $steal_queue = RT::Queue->new($RT::SystemUser);
    my $steal_queue_id;
    ($steal_queue_id, $msg) = $steal_queue->Create( Name => "Steal$$" );
    ok($steal_queue_id, "Got the queue? $msg");
    ok($steal_queue->id, "queue obj has id");
    my $status;
    ($status, $msg) = $steal_user->PrincipalObj->GrantRight( Right => 'ShowTicket', Object => $steal_queue );
    ok($status, "Gave 'SeeTicket' to our user? $msg");
    ($status, $msg) = $steal_user->PrincipalObj->GrantRight( Right => 'OwnTicket', Object => $steal_queue );
    ok($status, "Gave 'OwnTicket' to our user? $msg");
    ($status, $msg) = $steal_user->PrincipalObj->GrantRight( Right => 'StealTicket', Object => $steal_queue );
    ok($status, "Gave 'StealTicket' to our user? $msg");
    ($status, $msg) = $steal_user->PrincipalObj->GrantRight( Right => 'TakeTicket', Object => $steal_queue );
    ok($status, "Gave 'TakeTicket' to our user? $msg");

    # create a ticket to take/steal
    expect_send("create -t ticket set queue=$steal_queue_id subject='CLIStealTest-$$'", 'Creating ticket to steal...');
    expect_like(qr/Ticket \d+ created/, 'Created ticket');
    expect_handle->before() =~ /Ticket (\d+) created/;
    my $steal_ticket_id = $1;
    ok($steal_ticket_id, "Got ticket to steal id=$steal_ticket_id");

    # root takes the ticket
    expect_send("take $steal_ticket_id", 'root takes the ticket...');
    expect_like(qr/Owner changed from Nobody to root/, 'root took the ticket');

    # log in as the non-root user
    #expect_quit();      # this is apparently unnecessary, but I'll leave it in
                         # until I'm sure
    $ENV{'RTUSER'} = "fooser$$";
    $ENV{'RTPASSWD'} = 'foobar';
    expect_run( command => "$rt_tool_path shell", prompt => 'rt> ', quit => 'quit',);

    # user tries to take the ticket, fails
    # shouldn't be able to 'take' a ticket which someone else has taken out from
    # under you; that should produce an error.  should have to explicitly 
    # 'steal' it back from them.  'steal' can automatically 'take' a ticket,
    # though.
    expect_send("take $steal_ticket_id", 'user tries to take the ticket...');
    expect_like(qr/You can only take tickets that are unowned/, '...and fails.');
    expect_send("show ticket/$steal_ticket_id -f owner", 'Double-checking...');
    expect_like(qr/Owner: root/, '...no change.');

    # user steals the ticket
    expect_send("steal $steal_ticket_id", 'user tries to *steal* the ticket...');
    expect_like(qr/Owner changed from root to fooser$$/, '...and succeeds!');
    expect_send("show ticket/$steal_ticket_id -f owner", 'Double-checking...');
    expect_like(qr/Owner: fooser$$/, '...yup, it worked.');

    # log back in as root
    #expect_quit();     # ditto
    $ENV{'RTUSER'} = 'root';
    $ENV{'RTPASSWD'} = 'password';
    expect_run( command => "$rt_tool_path shell", prompt => 'rt> ', quit => 'quit',);

    # root steals the ticket back
    expect_send("steal $steal_ticket_id", 'root steals the ticket back...');
    expect_like(qr/Owner changed from fooser$$ to root/, '...and succeeds.');
}
# }}}

# {{{ test ticket linking
    my @link_relns = ( 'DependsOn', 'DependedOnBy', 'RefersTo', 'ReferredToBy',
                       'MemberOf', 'HasMember', );
    my %display_relns = map { $_ => $_ } @link_relns;
    $display_relns{HasMember} = 'Members';

    my $link1_id = ok_create_ticket( "LinkTicket1-$$" );
    my $link2_id = ok_create_ticket( "LinkTicket2-$$" );

    foreach my $reln (@link_relns) {
        # create link
        expect_send("link $link1_id $reln $link2_id", "Link by $reln...");
        expect_like(qr/Created link $link1_id $reln $link2_id/, 'Linked');
        expect_send("show ticket/$link1_id/links", "Checking creation of $reln...");
        expect_like(qr/$display_relns{reln}: [\w\d\.\-]+:\/\/[\w\d\.]+\/ticket\/$link2_id/, "Created link $reln");

        # delete link
        expect_send("link -d $link1_id $reln $link2_id", "Delete $reln...");
        expect_like(qr/Deleted link $link1_id $reln $link2_id/, 'Deleted');
        expect_send("show ticket/$link1_id/links", "Checking removal of $reln...");
        ok( expect_handle->before() !~ /\Q$display_relns{$reln}: \E[\w\d\.\-]+:\/\/[w\d\.]+\/ticket\/$link2_id/, "Removed link $reln" );
        #expect_unlike(qr/\Q$reln: \E[\w\d\.]+\Q://\E[w\d\.]+\/ticket\/$link2_id/, "Removed link $reln");

    }
# }}}


# helper function
sub ok_create_ticket {
    my $subject = shift;

    expect_send("create -t ticket set subject='$subject'", 'Creating ticket...');
    expect_like(qr/Ticket \d+ created/, "Created ticket '$subject'");
    expect_handle->before() =~ /Ticket (\d+) created/;
    my $id = $1;
    ok($id, "Got ticket id=$id");
    
    return $id;
}

# wrap up all the file handling stuff for attachment testing
sub check_attachment {
    my $attachment_path = shift;
    (my $filename = $attachment_path) =~ s/.*\/(.*?)$/$1/;
    expect_send("comment -m 'attach file' -a $attachment_path $ticket_id", "Adding an attachment ($filename)");
    expect_like(qr/Message recorded/, "Added the attachment");
    expect_send("show ticket/$ticket_id/attachments","Finding Attachment");
    my $attachment_regex = qr/(\d+):\s+$filename/;
    expect_like($attachment_regex,"Attachment Uploaded");
    expect_handle->before() =~ $attachment_regex;
    my $attachment_id = $1;
    expect_send("show ticket/$ticket_id/attachments/$attachment_id/content","Fetching Attachment");
    open (my $fh, $attachment_path) or die "Can't open $attachment_path: $!";
    my $attachment_content = do { local($/); <$fh> };
    close $fh;
    chomp $attachment_content;
    expect_is($attachment_content,"Attachment contains original text");
}

1;
