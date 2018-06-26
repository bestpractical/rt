use strict;
use warnings;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use RT::Test tests => undef;

my $cookie_jar = HTTP::Cookies->new;
my ($baseurl, $agent) = RT::Test->started_ok;


# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

# create a regression queue if it doesn't exist
my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

my $url = $agent->rt_base_url;
ok $agent->login, "logged in";


my $response = $agent->get($url."Search/Build.html");
ok $response->is_success, "Fetched ". $url ."Search/Build.html";

sub getQueryFromForm {
    my $agent = shift;
    $agent->form_name('BuildQuery');
    # This pulls out the "hidden input" query from the page
    my $q = $agent->current_form->find_input("Query")->value;
    $q =~ s/^\s+//g;
    $q =~ s/\s+$//g;
    $q =~ s/\s+/ /g;
    return $q;
}

sub selectedClauses {
    my $agent = shift;
    my @clauses = grep { defined } map { $_->value } $agent->current_form->find_input("clauses");
    return [ @clauses ];
}


diag "add the first condition";
{
    ok $agent->form_name('BuildQuery'), "found the form once";
    $agent->field("ActorField", "Owner");
    $agent->field("ActorOp", "=");
    $agent->field("ValueOfActor", "Nobody");
    $agent->submit;
    is getQueryFromForm($agent), "Owner = 'Nobody'", 'correct query';
}

diag "set the next condition";
{
    ok($agent->form_name('BuildQuery'), "found the form again");
    $agent->field("QueueOp", "!=");
    $agent->field("ValueOfQueue", "Regression");
    $agent->submit;
    is getQueryFromForm($agent), "Owner = 'Nobody' AND Queue != 'Regression'",
        'correct query';
}

diag "We're going to delete the owner";
{
    $agent->select("clauses", ["0"] );
    $agent->click("DeleteClause");
    ok $agent->form_name('BuildQuery'), "found the form";
    is getQueryFromForm($agent), "Queue != 'Regression'", 'correct query';
}

diag "add a cond with OR and se number by the way";
{
    $agent->field("AndOr", "OR");
    $agent->select("idOp", ">");
    $agent->field("ValueOfid" => "1234");
    $agent->click("AddClause");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm($agent), "Queue != 'Regression' OR id > 1234",
        "added something as OR, and number not quoted";
    is_deeply selectedClauses($agent), ["1"], 'the id that we just entered is still selected';

}

diag "Move the second one up a level";
{
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm($agent), "id > 1234 OR Queue != 'Regression'", "moved up one";
    is_deeply selectedClauses($agent), ["0"], 'the one we moved up is selected';
}

diag "Move the second one right";
{
    $agent->click("Right");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm($agent), "Queue != 'Regression' OR ( id > 1234 )",
        "moved over to the right (and down)";
    is_deeply selectedClauses($agent), ["2"], 'the one we moved right is selected';
}

diag "Move the block up";
{
    $agent->select("clauses", ["1"]);
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    is getQueryFromForm($agent), "( id > 1234 ) OR Queue != 'Regression'", "moved up";
    is_deeply selectedClauses($agent), ["0"], 'the one we moved up is selected';
}


diag "Can not move up the top most clause";
{
    $agent->select("clauses", ["0"]);
    $agent->click("Up");
    ok $agent->form_name('BuildQuery'), "found the form again";
    $agent->content_contains("error: can&#39;t move up", "i shouldn't have been able to hit up");
    is_deeply selectedClauses($agent), ["0"], 'the one we tried to move is selected';
}

diag "Can not move left the left most clause";
{
    $agent->click("Left");
    ok($agent->form_name('BuildQuery'), "found the form again");
    $agent->content_contains("error: can&#39;t move left", "i shouldn't have been able to hit left");
    is_deeply selectedClauses($agent), ["0"], 'the one we tried to move is selected';
}

diag "Add a condition into a nested block";
{
    $agent->select("clauses", ["1"]);
    $agent->select("ValueOfStatus" => "stalled");
    $agent->submit;
    ok $agent->form_name('BuildQuery'), "found the form again";
    is_deeply selectedClauses($agent), ["2"], 'the one we added is only selected';
    is getQueryFromForm($agent),
        "( id > 1234 AND Status = 'stalled' ) OR Queue != 'Regression'",
        "added new one";
}

diag "click advanced, enter 'C1 OR ( C2 AND C3 )', apply, aggregators should stay the same.";
{
    my $response = $agent->get($url."Search/Edit.html");
    ok( $response->is_success, "Fetched /Search/Edit.html" );
    ok($agent->form_name('BuildQueryAdvanced'), "found the form");
    $agent->field("Query", "Status = 'new' OR ( Status = 'open' AND Subject LIKE 'office' )");
    $agent->submit;
    is( getQueryFromForm($agent),
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


# create a custom field with nonascii name and try to add a condition
{
    my $cf = RT::CustomField->new( RT->SystemUser );
    $cf->LoadByName( Name => "\x{442}", LookupType => RT::Ticket->CustomFieldLookupType, ObjectId => 0 );
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
    $agent->field("ValueOfCF.{\x{442}}", "\x{441}");
    $agent->submit();
    is( getQueryFromForm($agent),
        "CF.{\x{442}} LIKE '\x{441}'",
        "no changes, no duplicate condition with badly encoded text"
    );

   $cf->SetDisabled(1);
}

diag "input a condition, select (several conditions), click delete";
{
    my $response = $agent->get( $url."Search/Edit.html" );
    ok $response->is_success, "Fetched /Search/Edit.html";
    ok $agent->form_name('BuildQueryAdvanced'), "found the form";
    $agent->field("Query", "( Status = 'new' OR Status = 'open' )");
    $agent->submit;
    is( getQueryFromForm($agent),
        "( Status = 'new' OR Status = 'open' )",
        "query is the same"
    );
    $agent->select("clauses", [qw(0 1 2)]);
    $agent->field( ValueOfid => 10 );
    $agent->click("DeleteClause");

    is( getQueryFromForm($agent),
        "id < 10",
        "replaced query successfuly"
    );
}

diag "send query with not quoted negative number";
{
    my $response = $agent->get($url."Search/Build.html?Query=Priority%20>%20-2");
    ok( $response->is_success, "Fetched " . $url."Search/Build.html" );

    is( getQueryFromForm($agent),
        "Priority > -2",
        "query is the same"
    );
}

diag "click advanced, enter an invalid SQL IS restriction, apply and check that we corrected it";
{
    my $response = $agent->get($url."Search/Edit.html");
    ok( $response->is_success, "Fetched /Search/Edit.html" );
    ok($agent->form_name('BuildQueryAdvanced'), "found the form");
    $agent->field("Query", "Requestor.EmailAddress IS 'FOOBAR'");
    $agent->submit;
    is( getQueryFromForm($agent),
        "Requestor.EmailAddress IS NULL",
        "foobar is replaced by NULL"
    );
}

diag "click advanced, enter an invalid SQL IS NOT restriction, apply and check that we corrected it";
{
    my $response = $agent->get($url."Search/Edit.html");
    ok( $response->is_success, "Fetched /Search/Edit.html" );
    ok($agent->form_name('BuildQueryAdvanced'), "found the form");
    $agent->field("Query", "Requestor.EmailAddress IS NOT 'FOOBAR'");
    $agent->submit;
    is( getQueryFromForm($agent),
        "Requestor.EmailAddress IS NOT NULL",
        "foobar is replaced by NULL"
    );
}

diag "click advanced, enter a valid SQL, but the field is lower cased";
{
    my $response = $agent->get($url."Search/Edit.html");
    ok( $response->is_success, "Fetched /Search/Edit.html" );
    ok($agent->form_name('BuildQueryAdvanced'), "found the form");
    $agent->field("Query", "status = 'new'");
    $agent->submit;
    $agent->content_lacks( 'Unknown field:', 'no "unknown field" warning' );
    is( getQueryFromForm($agent),
        "Status = 'new'",
        "field's case is corrected"
    );
}

diag "make sure skipped order by field doesn't break search";
{
    my $t = RT::Test->create_ticket( Queue => 'General', Subject => 'test' );
    ok $t && $t->id, 'created a ticket';

    $agent->get_ok($url."Search/Edit.html");
    ok($agent->form_name('BuildQueryAdvanced'), "found the form");
    $agent->field("Query", "id = ". $t->id);
    $agent->submit;

    $agent->follow_link_ok({id => 'page-results'});
    ok( $agent->find_link(
        text      => $t->id,
        url_regex => qr{/Ticket/Display\.html},
    ), "link to the ticket" );

    $agent->follow_link_ok({id => 'page-edit_search'});
    $agent->form_name('BuildQuery');
    $agent->field("OrderBy", 'Requestor.EmailAddress', 3);
    $agent->submit;
    $agent->form_name('BuildQuery');
    is $agent->value('OrderBy', 1), 'id';
    is $agent->value('OrderBy', 2), '';
    is $agent->value('OrderBy', 3), 'Requestor.EmailAddress';

    $agent->follow_link_ok({id => 'page-results'});
    ok( $agent->find_link(
        text      => $t->id,
        url_regex => qr{/Ticket/Display\.html},
    ), "link to the ticket" );
}

diag "make sure the list of columns available in the 'Order by' dropdowns are complete";
{
    $agent->get_ok($url . 'Search/Build.html');

    my @orderby = qw(
        AdminCc.EmailAddress
        Cc.EmailAddress
        Created
        Creator
        Custom.Ownership
        Due
        FinalPriority
        InitialPriority
        LastUpdated
        LastUpdatedBy
        Owner
        Priority
        Queue
        Requestor.EmailAddress
        Resolved
        SLA
        Started
        Starts
        Status
        Subject
        TimeEstimated
        TimeLeft
        TimeWorked
        Told
        Type
        id
    );

    my $orderby = join(' ', sort @orderby);

    my @scraped_orderbys = $agent->scrape_text_by_attr('name', 'OrderBy');

    my $first_orderby = shift @scraped_orderbys;
    is ($first_orderby, $orderby);

    foreach my $scraped_orderby ( @scraped_orderbys ) {
            is ($scraped_orderby, '[none] '.$orderby);
    }

    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'Location',
        Queue => 'General',
        Type  => 'FreeformSingle', );
    isa_ok( $cf, 'RT::CustomField' );

    ok($agent->form_name('BuildQuery'), "found the form");
    $agent->field("ValueOfQueue", "General");
    $agent->submit;

    push @orderby, 'CustomField.{Location}';

    $orderby = join(' ', sort @orderby);

    @scraped_orderbys = $agent->scrape_text_by_attr('name', 'OrderBy');

    $first_orderby = shift @scraped_orderbys;
    is ($first_orderby, $orderby);

    foreach my $scraped_orderby ( @scraped_orderbys ) {
        is ($scraped_orderby, '[none] '.$orderby);
    }

    $cf->SetDisabled(1);
}

diag "make sure active and inactive statuses generate the correct query";
{
    $agent->get_ok( $url . '/Search/Build.html?NewQuery=1' );
    ok( $agent->form_name( 'BuildQuery' ), "found the form" );
    $agent->field( ValueOfStatus => 'active' );
    $agent->click( 'AddClause' );
    is getQueryFromForm( $agent ), "Status = '__Active__'", "active status generated the correct query";

    $agent->get_ok( $url . '/Search/Build.html?NewQuery=1' );
    ok( $agent->form_name( 'BuildQuery' ), "found the form" );
    $agent->field( ValueOfStatus => 'inactive' );
    $agent->click( 'AddClause' );
    is getQueryFromForm( $agent ), "Status = '__Inactive__'", "inactive status generated the correct query";
}

diag "test null values";
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'foo',
        Type  => 'FreeformSingle',
        Queue => 0,
    );

    RT::Test->create_tickets(
        { Queue   => 'General' },
        { Subject => 'ticket bar', 'CustomField-' . $cf->id => 'bar' },
        { Subject => 'ticket baz', 'CustomField-' . $cf->id => 'baz' },
        { Subject => 'ticket null' },
    );

    $agent->get_ok( '/Search/Build.html?NewQuery=1' );
    $agent->submit_form(
        form_name => 'BuildQuery',
        fields    => { 'CF.{foo}Op' => '=', 'ValueOfCF.{foo}' => 'NULL', },
        button    => 'DoSearch',
    );

    $agent->title_is( 'Found 2 tickets', 'found 2 tickets with CF.{foo} IS NULL' );
    # the other ticket was created before the block
    $agent->content_contains( 'ticket null', 'has ticket null' );
    $agent->follow_link_ok( { text => 'Advanced' } );
    $agent->text_lacks( q[CF.{foo} = 'NULL'] );
    $agent->text_contains( 'CF.{foo} IS NULL', q["= 'NULL'" is converted to "IS NULL"] );

    $agent->get_ok( '/Search/Build.html?NewQuery=1' );
    $agent->submit_form(
        form_name => 'BuildQuery',
        fields    => { 'CF.{foo}Op' => '!=', 'ValueOfCF.{foo}' => 'NULL', },
        button    => 'DoSearch',
    );

    $agent->title_is( 'Found 2 tickets', 'found 2 ticket with CF.{foo} IS NOT NULL' );
    $agent->content_contains( 'ticket bar', 'has ticket bar' );
    $agent->content_contains( 'ticket baz', 'has ticket baz' );
    $agent->follow_link_ok( { text => 'Advanced' } );
    $agent->text_lacks( q[CF.{foo} != 'NULL'] );
    $agent->text_contains( 'CF.{foo} IS NOT NULL', q["!= 'NULL'" is converted to "IS NOT NULL"] );
}

done_testing;
