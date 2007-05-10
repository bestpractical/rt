#!/usr/bin/perl

use strict;
use Test::More tests => 20;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;
use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

# get the top page
my $url = RT->Config->Get('WebURL');
diag $url;
$agent->get($url);

is ($agent->{'status'}, 200, "Loaded a page");


# {{{ test a login

# follow the link marked "Login"

ok($agent->{form}->find_input('user'));

ok($agent->{form}->find_input('pass'));
ok ($agent->{'content'} =~ /username:/i);
$agent->field( 'user' => 'root' );
$agent->field( 'pass' => 'password' );
# the field isn't named, so we have to click link 0
$agent->click(0);
is($agent->{'status'}, 200, "Fetched the page ok");
ok( $agent->{'content'} =~ /Logout/i, "Found a logout link");



$agent->get($url."Ticket/Create.html?Queue=1");
is ($agent->{'status'}, 200, "Loaded Create.html");
$agent->form_number(3);
# Start with a string containing characters in latin1
my $string = "I18N Web Testing זרו";
Encode::from_to($string, 'iso-8859-1', 'utf8');
$agent->field('Subject' => "Ticket with utf8 body");
$agent->field('Content' => $string);
ok($agent->submit(), "Created new ticket with $string as Content");
like( $agent->{'content'}, qr{$string} , "Found the content");
ok($agent->{redirected_uri}, "Did redirection");


$agent->get($url."Ticket/Create.html?Queue=1");
is ($agent->{'status'}, 200, "Loaded Create.html");
$agent->form_number(3);
# Start with a string containing characters in latin1
$string = "I18N Web Testing זרו";
Encode::from_to($string, 'iso-8859-1', 'utf8');
$agent->field('Subject' => $string);
$agent->field('Content' => "Ticket with utf8 subject");
ok($agent->submit(), "Created new ticket with $string as Subject");

like( $agent->{'content'}, qr{$string} , "Found the content");

# Update time worked in hours
$agent->follow_link( text_regex => qr/Basics/ );
$agent->submit_form( form_number => 3,
    fields => { TimeWorked => 5, 'TimeWorked-TimeUnits' => "hours" }
);

like ($agent->{'content'}, qr/to &#39;300&#39;/, "5 hours is 300 minutes");

# }}}

# {{{ Query Builder tests

my $response = $agent->get($url."Search/Build.html");
ok( $response->is_success, "Fetched " . $url."Search/Build.html" );

# Parsing TicketSQL
#
# Adding items

# set the first value
ok($agent->form_name('BuildQuery'));
$agent->field("AttachmentField", "Subject");
$agent->field("AttachmentOp", "LIKE");
$agent->field("ValueOfAttachment", "aaa");
$agent->submit("AddClause");

# set the next value
ok($agent->form_name('BuildQuery'));
$agent->field("AttachmentField", "Subject");
$agent->field("AttachmentOp", "LIKE");
$agent->field("ValueOfAttachment", "bbb");
$agent->submit("AddClause");

ok($agent->form_name('BuildQuery'));

# get the query
my $query = $agent->current_form->find_input("Query")->value;
# strip whitespace from ends
$query =~ s/^\s*//g;
$query =~ s/\s*$//g;

# collapse other whitespace
$query =~ s/\s+/ /g;

is ($query, "Subject LIKE 'aaa' AND Subject LIKE 'bbb'");

# - new items go one level down
# - add items at currently selected level
# - if nothing is selected, add at end, one level down
#
# move left
# - error if nothing selected
# - same item should be selected after move
# - can't move left if you're at the top level
#
# move right
# - error if nothing selected
# - same item should be selected after move
# - can always move right (no max depth...should there be?)
#
# move up
# - error if nothing selected
# - same item should be selected after move
# - can't move up if you're first in the list
#
# move down
# - error if nothing selected
# - same item should be selected after move
# - can't move down if you're last in the list
#
# toggle
# - error if nothing selected
# - change all aggregators in the grouping
# - don't change any others
#
# delete
# - error if nothing selected
# - delete currently selected item
# - delete all children of a grouping
# - if delete leaves a node with no children, delete that, too
# - what should be selected?
#
# Clear
# - clears entire query
# - clears it from the session, too

# }}}


1;
