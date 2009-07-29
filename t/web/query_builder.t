#!/usr/bin/perl

use strict;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;
use RT::Test tests => 42;

my $cookie_jar = HTTP::Cookies->new;
my ($baseurl, $agent) = RT::Test->started_ok;


# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

# create a regression queue if it doesn't exist
my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

my $url = $agent->rt_base_url;
ok $agent->login, "logged in";

# {{{ Query Builder tests

my $response = $agent->get($url."Search/Build.html");
ok $response->is_success, "Fetched ". $url ."Search/Build.html";

sub getQueryFromForm {
    $agent->form_name('BuildQuery');
    # This pulls out the "hidden input" query from the page
    my $q = $agent->current_form->find_input("Query")->value;
    $q =~ s/^\s+//g;
    $q =~ s/\s+$//g;
    $q =~ s/\s+/ /g;
    return $q;
}

sub selectedClauses {
    my @clauses = grep { defined } map { $_->value } $agent->current_form->find_input("clauses");
    return [ @clauses ];
}


diag "add the first condition" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->form_name('BuildQuery'), "found the form once";
    $agent->field("ActorField", "Owner");
    $agent->field("ActorOp", "=");
    $agent->field("ValueOfActor", "Nobody");
    $agent->submit;
    is getQueryFromForm, "Owner = 'Nobody'", 'correct query';
}

diag "set the next condition" if $ENV{'TEST_VERBOSE'};
{
    ok($agent->form_name('BuildQuery'), "found the form again");
    $agent->field("QueueOp", "!=");
    $agent->field("ValueOfQueue", "Regression");
    $agent->submit;
    is getQueryFromForm, "Owner = 'Nobody' AND Queue != 'Regression'",
        'correct query';
}

diag "We're going to delete the owner" if $ENV{'TEST_VERBOSE'};
{
    $agent->select("clauses", ["0"] );
    $agent->click("DeleteClause");
    ok $agent->form_name('BuildQuery'), "found the form";
    is getQueryFromForm, "Queue != 'Regression'", 'correct query';
}

diag "add a cond with OR and se number by the way" if $ENV{'TEST_VERBOSE'};
{
    $agent->field("AndOr", "OR");
    $agent->select("idOp", ">");
    $agent->field("ValueOfid" => "1234");
    $agent->click("AddClause");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm, "Queue != 'Regression' OR id > 1234",
        "added something as OR, and number not quoted";
    is_deeply selectedClauses, ["1"], 'the id that we just entered is still selected';

}

diag "Move the second one up a level" if $ENV{'TEST_VERBOSE'};
{
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm, "id > 1234 OR Queue != 'Regression'", "moved up one";
    is_deeply selectedClauses, ["0"], 'the one we moved up is selected';
}

diag "Move the second one right" if $ENV{'TEST_VERBOSE'};
{
    $agent->click("Right");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm, "Queue != 'Regression' OR ( id > 1234 )",
        "moved over to the right (and down)";
    is_deeply selectedClauses, ["2"], 'the one we moved right is selected';
}

diag "Move the block up" if $ENV{'TEST_VERBOSE'};
{
    $agent->select("clauses", ["1"]);
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm, "( id > 1234 ) OR Queue != 'Regression'", "moved up";
    is_deeply selectedClauses, ["0"], 'the one we moved up is selected';
}


diag "Can not move up the top most clause" if $ENV{'TEST_VERBOSE'};
{
    $agent->select("clauses", ["0"]);
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    $agent->content_like(qr/error: can\S+t move up/, "i shouldn't have been able to hit up");
    is_deeply selectedClauses, ["0"], 'the one we tried to move is selected';
}

diag "Can not move left the left most clause" if $ENV{'TEST_VERBOSE'};
{
    $agent->click("Left");
    ok($agent->form_name('BuildQuery'), "found the form again");
    $agent->content_like(qr/error: can\S+t move left/, "i shouldn't have been able to hit left");
    is_deeply selectedClauses, ["0"], 'the one we tried to move is selected';
}

diag "Add a condition into a nested block" if $ENV{'TEST_VERBOSE'};
{
    $agent->select("clauses", ["1"]);
    $agent->select("ValueOfStatus" => "stalled");
    $agent->submit;
    ok $agent->form_name('BuildQuery'), "found the form again";
    is_deeply selectedClauses, ["2"], 'the one we added is only selected';
    is getQueryFromForm,
        "( id > 1234 AND Status = 'stalled' ) OR Queue != 'Regression'",
        "added new one";
}

diag "click advanced, enter 'C1 OR ( C2 AND C3 )', apply, aggregators should stay the same."
    if $ENV{'TEST_VERBOSE'};
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
    $agent->field("ValueOf'CF.{\x{442}}'", "\x{441}");
    $agent->submit();
    is( getQueryFromForm,
        "'CF.{\x{442}}' LIKE '\x{441}'",
        "no changes, no duplicate condition with badly encoded text"
    );

}

diag "input a condition, select (several conditions), click delete"
    if $ENV{'TEST_VERBOSE'};
{
    my $response = $agent->get( $url."Search/Edit.html" );
    ok $response->is_success, "Fetched /Search/Edit.html";
    ok $agent->form_number(3), "found the form";
    $agent->field("Query", "( Status = 'new' OR Status = 'open' )");
    $agent->submit;
    is( getQueryFromForm,
        "( Status = 'new' OR Status = 'open' )",
        "query is the same"
    );
    $agent->select("clauses", [qw(0 1 2)]);
    $agent->field( ValueOfid => 10 );
    $agent->click("DeleteClause");

    is( getQueryFromForm,
        "id < 10",
        "replaced query successfuly"
    );
}

1;
