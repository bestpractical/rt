#!/usr/bin/perl

use strict;
use Test::More tests => 39;
use Test::WWW::Mechanize;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;
my $agent = Test::WWW::Mechanize->new();

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

use RT;
RT::LoadConfig();
RT::Init();

# create a regression queue if it doesn't exist
{
    my $queue = RT::Queue->new( $RT::SystemUser );
    $queue->Load( 'Regression' );
    if ( $queue->id ) {
        ok(1, "queue 'Regression' exists");
    } else {
        $queue->Create( Name => 'Regression' );
        ok($queue->id, "created queue 'Regression'");
    }
}

# get the top page
my $url = RT->Config->Get('WebURL');
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
ok($agent->form_name('BuildQuery'), "found the form once");
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

sub getQueryFromForm {
    $agent->form_name('BuildQuery');
    # This pulls out the "hidden input" query from the page
    my $q = $agent->current_form->find_input("Query")->value;
    $q =~ s/^\s+//g;
    $q =~ s/\s+$//g;
    $q =~ s/\s+/ /g;
    return $q;
}

is (getQueryFromForm, "Owner = 'Nobody' AND Queue != 'Regression'");

# We're going to delete the owner

$agent->select("clauses", ["0"] );

$agent->click("DeleteClause");

ok($agent->form_name('BuildQuery'), "found the form a fourth time");

is (getQueryFromForm, "Queue != 'Regression'");

$agent->field("AndOr", "OR");

$agent->select("idOp", ">");

$agent->field("ValueOfid" => "1234");

$agent->click("AddClause");

ok($agent->form_name('BuildQuery'), "found the form again");
TODO: {
  local $TODO = "query builder incorrectly quotes numbers";
  is(getQueryFromForm, "Queue != 'Regression' OR id > 1234", "added something as OR, and number not quoted");
}

sub selectedClauses {
    my @clauses = grep { defined } map { $_->value } $agent->current_form->find_input("clauses");
    return [ @clauses ];
}


is_deeply(selectedClauses, ["1"], 'the id that we just entered is still selected');

# Move the second one up a level
$agent->click("Up"); 

ok($agent->form_name('BuildQuery'), "found the form again");
is(getQueryFromForm, "id > 1234 OR Queue != 'Regression'", "moved up one");

is_deeply(selectedClauses, ["0"], 'the one we moved up is selected');

$agent->click("Right");

ok($agent->form_name('BuildQuery'), "found the form again");
is(getQueryFromForm, "Queue != 'Regression' OR ( id > 1234 )", "moved over to the right (and down)");
is_deeply(selectedClauses, ["2"], 'the one we moved right is selected');

$agent->select("clauses", ["1"]);

$agent->click("Up");

ok($agent->form_name('BuildQuery'), "found the form again");
is(getQueryFromForm, "( id > 1234 ) OR Queue != 'Regression'", "moved up");

$agent->select("clauses", ["0"]); # this is a null clause
$agent->click("Up");
ok($agent->form_name('BuildQuery'), "found the form again");
$agent->content_like(qr/error: can\S+t move up/, "i shouldn't have been able to hit up");

$agent->click("Left");
ok($agent->form_name('BuildQuery'), "found the form again");
$agent->content_like(qr/error: can\S+t move left/, "i shouldn't have been able to hit left");

$agent->select("clauses", ["1"]);
$agent->select("ValueOfStatus" => "stalled");
$agent->submit;
ok($agent->form_name('BuildQuery'), "found the form again");
is_deeply(selectedClauses, ["2"], 'the one we added is selected');
is( getQueryFromForm, "( id > 1234 AND Status = 'stalled' ) OR Queue != 'Regression'", "added new one" );

# click advanced, enter "C1 OR ( C2 AND C3 )", apply, aggregators should stay the same.
{
    my $response = $agent->get($url."Search/Edit.html");
    ok( $response->is_success, "Fetched /Search/Edit.html" );
    ok($agent->form_number(3), "found the form");
    $agent->field("Query", "Status = 'new' OR ( Status = 'open' AND Subject LIKE 'office' )");
    $agent->submit;
    is( getQueryFromForm,
        "Status = 'new' OR ( Status = 'open' AND Subject LIKE 'office' )",
        "no aggregators change"
    );
}

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

# create a custom field with nonascii name and try to add a condition
{
    my $cf = RT::CustomField->new( $RT::SystemUser );
    $cf->LoadByName( Name => "\x{442}", Queue => 0 );
    if ( $cf->id ) {
        is($cf->Type, 'Freeform', 'loaded and type is correct');
    } else {
        my ($return, $msg) = $cf->Create(
            Name => "\x{442}",
            Queue => 0,
            Type => 'Freeform',
        );
        ok($return, 'created CF') or diag "error: $msg";
    }

    my $response = $agent->get($url."Search/Build.html?NewQuery=1");
    ok( $response->is_success, "Fetched " . $url."Search/Build.html" );

    ok($agent->form_name('BuildQuery'), "found the form once");
    $agent->field("ValueOf'CF.{\321\202}'", "\321\201");
    $agent->submit();
    is( getQueryFromForm,
        "'CF.{\321\202}' LIKE '\321\201'",
        "no changes, no duplicate condition with badly encoded text"
    );

}

1;
