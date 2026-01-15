use strict;
use warnings;

use RT::Test tests => undef,
    config => 'Set( %FullTextSearch, Enable => 1, Indexed => 0 );';
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create( Name => 'other' );
ok( $queue->id, 'created queue other');

my $two_words_queue = RT::Test->load_or_create_queue(
    Name => 'Two Words',
);
ok $two_words_queue && $two_words_queue->id, 'loaded or created a queue';

my $root = RT::Test->load_or_create_user( Name => 'root' );

{
    my $tickets = RT::Tickets->new( RT->SystemUser );

    require RT::Search::Simple;
    my $parser = RT::Search::Simple->new(
        TicketsObj => $tickets,
        Argument   => '',
    );
    is $parser->QueryToSQL("foo"), "( Subject LIKE 'foo' OR Description LIKE 'foo' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("1 foo"), "( Subject LIKE '1 foo' OR Description LIKE '1 foo' ) AND ( Status = '__Active__' )", "multi-word input treated as phrase";
    is $parser->QueryToSQL("1"), "( Id = 1 )", "correct parsing";
    is $parser->QueryToSQL("#1"), "( Id = 1 )", "correct parsing";
    is $parser->QueryToSQL("'1'"), "( Subject LIKE '1' OR Description LIKE '1' ) AND ( Status = '__Active__' )", "correct parsing";

    is $parser->QueryToSQL("foo bar"),
        "( Subject LIKE 'foo bar' OR Description LIKE 'foo bar' ) AND ( Status = '__Active__' )",
        "multi-word input treated as phrase";
    is $parser->QueryToSQL("'foo bar'"),
        "( Subject LIKE 'foo bar' OR Description LIKE 'foo bar' ) AND ( Status = '__Active__' )",
        "correct parsing";

    # Status words in phrase: "open" is a valid status, test position handling
    is $parser->QueryToSQL("error in open search"),
        "( Subject LIKE 'error in open search' OR Description LIKE 'error in open search' ) AND ( Status = '__Active__' )",
        "status word in middle of phrase is part of phrase";
    is $parser->QueryToSQL("error in search open"),
        "( Subject LIKE 'error in search' OR Description LIKE 'error in search' ) AND ( Status = 'open' )",
        "status word at end of phrase is status filter";

    # Quoted phrases preserve status words as literal text
    is $parser->QueryToSQL("'error in open search'"),
        "( Subject LIKE 'error in open search' OR Description LIKE 'error in open search' ) AND ( Status = '__Active__' )",
        "single-quoted phrase with status word in middle";
    is $parser->QueryToSQL('"error in open search"'),
        "( Subject LIKE 'error in open search' OR Description LIKE 'error in open search' ) AND ( Status = '__Active__' )",
        "double-quoted phrase with status word in middle";
    is $parser->QueryToSQL("'error in search open'"),
        "( Subject LIKE 'error in search open' OR Description LIKE 'error in search open' ) AND ( Status = '__Active__' )",
        "single-quoted phrase with status word at end stays literal";
    is $parser->QueryToSQL('"error in search open"'),
        "( Subject LIKE 'error in search open' OR Description LIKE 'error in search open' ) AND ( Status = '__Active__' )",
        "double-quoted phrase with status word at end stays literal";

    # Status word outside quotes is treated as status filter
    is $parser->QueryToSQL("'error in search' open"),
        "( Subject LIKE 'error in search' OR Description LIKE 'error in search' ) AND ( Status = 'open' )",
        "single-quoted phrase with status word outside quotes";
    is $parser->QueryToSQL('"error in search" open'),
        "( Subject LIKE 'error in search' OR Description LIKE 'error in search' ) AND ( Status = 'open' )",
        "double-quoted phrase with status word outside quotes";

    is $parser->QueryToSQL("'foo \\' bar'"),
        "( Subject LIKE 'foo \\' bar' OR Description LIKE 'foo \\' bar' ) AND ( Status = '__Active__' )",
        "correct parsing";
    is $parser->QueryToSQL('"foo \' bar"'),
        "( Subject LIKE 'foo \\' bar' OR Description LIKE 'foo \\' bar' ) AND ( Status = '__Active__' )",
        "correct parsing";
    is $parser->QueryToSQL('"\f\o\o"'),
        "( Subject LIKE '\\\\f\\\\o\\\\o' OR Description LIKE '\\\\f\\\\o\\\\o' ) AND ( Status = '__Active__' )",
        "correct parsing";

    is $parser->QueryToSQL("General"), "( Queue = 'General' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("'Two Words'"), "( Subject LIKE 'Two Words' OR Description LIKE 'Two Words' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("queue:'Two Words'"), "( Queue = 'Two Words' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("subject:'Two Words'"), "( Status = '__Active__' ) AND ( Subject LIKE 'Two Words' )", "correct parsing";

    is $parser->QueryToSQL("me"), "( Owner.id = '__CurrentUser__' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("'me'"), "( Subject LIKE 'me' OR Description LIKE 'me' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("owner:me"), "( Owner.id = '__CurrentUser__' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("owner:'me'"), "( Owner = 'me' ) AND ( Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL('owner:root@localhost'), "( Owner.EmailAddress = 'root\@localhost' ) AND ( Status = '__Active__' )", "Email address as owner";

    is $parser->QueryToSQL("resolved me"), "( Owner.id = '__CurrentUser__' ) AND ( Status = 'resolved' )", "correct parsing";
    is $parser->QueryToSQL("resolved active me"), "( Owner.id = '__CurrentUser__' ) AND ( Status = 'resolved' OR Status = '__Active__' )", "correct parsing";
    is $parser->QueryToSQL("status:active"), "( Status = '__Active__' )", "Explicit active search";
    is $parser->QueryToSQL("status:'active'"), "( Status = 'active' )", "Quoting active makes it the actual word";
    is $parser->QueryToSQL("inactive me"), "( Owner.id = '__CurrentUser__' ) AND ( Status = '__Inactive__' )", "correct parsing";

    is $parser->QueryToSQL("cf.Foo:bar"), "( 'CF.{Foo}' LIKE 'bar' ) AND ( Status = '__Active__' )", "correct parsing of CFs";
    is $parser->QueryToSQL(q{cf."don't foo?":'bar n\\' baz'}), qq/( 'CF.{don\\'t foo?}' LIKE 'bar n\\' baz' ) AND ( Status = '__Active__' )/, "correct parsing of CFs with quotes";
}

my $ticket_found_1 = RT::Test->create_ticket(
    Subject   => 'base ticket 1'.$$,
    Queue     => 'general',
    Owner     => $root->Id,
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 1',
);

my $ticket_found_2 = RT::Test->create_ticket(
    Subject   => 'base ticket 2'.$$,
    Queue     => 'general',
    Owner     => $root->Id,
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 2',
);

my $ticket_not_found = RT::Test->create_ticket(
    Subject   => 'not found subject' . $$,
    Queue     => 'other',
    Owner     => RT->Nobody->Id,
    Requestor => 'notfound@localhost',
    Content   => 'this is not found content',
);

ok($m->login, 'logged in');

my @queries = (
    'base ticket',            'root',
    'customsearch@localhost', 'requestor:customsearch',
    'subject:base',           'subject:"base ticket"',
    'queue:general',          'owner:root',
);

for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->text_contains( 'Found 2 tickets' );
    $m->text_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->text_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->text_lacks( 'not found subject', 'not found ticket is not found' );
}

$ticket_not_found->SetStatus('open');
is( $ticket_not_found->Status, 'open', 'status of not found ticket is open' );
@queries = qw/new status:new/;
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->text_contains( 'Found 2 tickets' );
    $m->text_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->text_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->text_lacks( 'not found subject', 'not found ticket is not found' );
}

@queries = ( 'fulltext:"base ticket 1"', "'base ticket 1'" );
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->text_contains( 'Found 1 ticket' );
    $m->text_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->text_lacks( 'base ticket 2',     'base ticket 2 is not found' );
    $m->text_lacks( 'not found subject', 'not found ticket is not found' );
}

# now let's test with ' or "
for my $quote ( q{'}, q{"} ) {
    my $user = RT::User->new($RT::SystemUser);
    is( ref($user), 'RT::User' );
    my ( $id, $msg ) = $user->Create(
        Name         => qq!foo${quote}bar!,
        EmailAddress => qq!foo${quote}bar$$\@example.com !,
        Privileged   => 1,
    );
    ok ($id, "Creating user - " . $msg );

    my ( $grantid, $grantmsg ) =
      $user->PrincipalObj->GrantRight( Right => 'OwnTicket' );
    ok( $grantid, $grantmsg );



    RT::Test->create_ticket(
        Subject   => qq!base${quote}ticket $$!,
        Queue     => 'general',
        Owner     => $user->Id,
        ( $quote eq q{'}
            ? (Requestor => qq!custom${quote}search\@localhost!)
            : () ),
        Content   => qq!this is base${quote}ticket with quote inside!,
    );

    @queries = (
        qq!fulltext:base${quote}ticket!,
        "base${quote}ticket",
        "owner:foo${quote}bar",
        "foo${quote}bar",

        # email doesn't allow " character
        $quote eq q{'}
        ? (
            "requestor:custom${quote}search\@localhost",
            "custom${quote}search\@localhost",
          )
        : (),
    );
    for my $q (@queries) {
        $m->form_with_fields('q');
        $m->field( q => $q );
        $m->submit;
        $m->text_contains( 'Found 1 ticket' );
        $m->text_contains( "base${quote}ticket", "base${quote}ticket is found" );
    }
}

# Create a CF
{
    my $cf = RT::CustomField->new(RT->SystemUser);
    ok( $cf->Create(Name => 'Foo', Type => 'Freeform', MaxValues => '1', Queue => 0) );
    ok $cf->Id;

    $ticket_found_1->AddCustomFieldValue( Field => 'Foo', Value => 'bar' );
    $ticket_found_2->AddCustomFieldValue( Field => 'Foo', Value => 'bar' );
    $ticket_not_found->AddCustomFieldValue( Field => 'Foo', Value => 'baz' );
    is( $ticket_found_1->FirstCustomFieldValue('Foo'), 'bar', 'cf value is ok' );
    is( $ticket_found_2->FirstCustomFieldValue('Foo'), 'bar', 'cf value is ok' );
    is( $ticket_not_found->FirstCustomFieldValue('Foo'), 'baz', 'cf value is ok' );

    @queries = qw/cf.Foo:bar/;
    for my $q (@queries) {
        $m->form_with_fields('q');
        $m->field( q => $q );
        $m->submit;
        $m->text_contains( 'Found 2 tickets' );
        $m->text_contains( 'base ticket 1', 'base ticket 1 is found' );
        $m->text_contains( 'base ticket 2', 'base ticket 2 is found' );
        $m->text_lacks( 'not found subject', 'not found ticket is not found' );
    }
}

done_testing;
