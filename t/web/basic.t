
use strict;
use warnings;

use RT::Test tests => 24;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;

# get the top page
{
    $agent->get($url);
    is ($agent->status, 200, "Loaded a page");
}

# test a login
{
    $agent->login('root' => 'password');
    # the field isn't named, so we have to click link 0
    is( $agent->status, 200, "Fetched the page ok");
    $agent->content_contains("Logout", "Found a logout link");
}

{
    $agent->goto_create_ticket(1);
    is ($agent->status, 200, "Loaded Create.html");
    $agent->form_name('TicketCreate');
    my $string = Encode::decode("UTF-8","I18N Web Testing æøå");
    $agent->field('Subject' => "Ticket with utf8 body");
    $agent->field('Content' => $string);
    ok($agent->submit, "Created new ticket with $string as Content");
    $agent->content_contains($string, "Found the content");
    ok($agent->{redirected_uri}, "Did redirection");

    {
        my $ticket = RT::Test->last_ticket;
        my $content = $ticket->Transactions->First->Content;
        like(
            $content, qr{$string},
            'content is there, API check'
        );
    }
}

{
    $agent->goto_create_ticket(1);
    is ($agent->status, 200, "Loaded Create.html");
    $agent->form_name('TicketCreate');

    my $string = Encode::decode( "UTF-8","I18N Web Testing æøå");
    $agent->field('Subject' => $string);
    $agent->field('Content' => "Ticket with utf8 subject");
    ok($agent->submit, "Created new ticket with $string as Content");
    $agent->content_contains($string, "Found the content");
    ok($agent->{redirected_uri}, "Did redirection");

    {
        my $ticket = RT::Test->last_ticket;
        is(
            $ticket->Subject, $string,
            'subject is correct, API check'
        );
    }
}

# Update time worked in hours
{
    $agent->follow_link( text_regex => qr/Basics/ );
    $agent->submit_form( form_name => 'TicketModify',
        fields => { TimeWorked => 5, 'TimeWorked-TimeUnits' => "hours" }
    );

    $agent->content_contains("5 hours", "5 hours is displayed");
    $agent->content_contains("300 min", "but minutes is also");
}


$agent->get( $url."static/images/test.png" );
my $file = RT::Test::get_relocatable_file(
  File::Spec->catfile(
    qw(.. .. share static images test.png)
  )
);
is(
    length($agent->content),
    -s $file,
    "got a file of the correct size ($file)",
);

#
# XXX: hey-ho, we have these tests in t/web/query-builder
# TODO: move everything about QB there

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

