#!/usr/bin/perl

use strict;
use Test::More tests => 13;
use WWW::Mechanize;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;
my $agent = WWW::Mechanize->new();

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

use RT;
RT::LoadConfig;

# get the top page
my $url = $RT::WebURL;
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

# }}}

# {{{ Query Builder tests

my $response = $agent->get($url."Search/Build.html");
ok( $response->is_success, "Fetched " . $url."Search/Build.html" );

# Adding items

# set the first value
ok($agent->form_name('BuildQuery'), "foud the form once");
$agent->field("ActorField", "Owner");
$agent->field("ActorOp", "=");
$agent->field("ValueOfActor", "Nobody");
$agent->submit();

# set the next value
ok($agent->form_name('BuildQuery'), "found the form again");
$agent->field("QueueOp", "!=");
$agent->field("ValueOfQueue", "Regression");
$agent->submit();

ok($agent->form_name('BuildQuery'), "found the form a third time");

# get the query
my $query = $agent->current_form->find_input("Query")->value;
# strip whitespace from ends
$query =~ s/^\s*//g;
$query =~ s/\s*$//g;

# collapse other whitespace
$query =~ s/\s+/ /g;

is ($query, "Owner = 'Nobody' AND Queue != 'Regression'");

# We're going to delete the owner

$agent->select("clauses", ["0"] );

$agent->click("DeleteClause");

ok($agent->form_name('BuildQuery'), "found the form a fourth time");

# get the query
$query = $agent->current_form->find_input("Query")->value;
# strip whitespace from ends
$query =~ s/^\s*//g;
$query =~ s/\s*$//g;

# collapse other whitespace
$query =~ s/\s+/ /g;

is ($query, "Queue != 'Regression'");

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
