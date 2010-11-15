#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 77, config => 'Set( %FullTextSearch, Enable => 1, Indexed => 0 );';
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create( Name => 'other' );
ok( $queue->id, 'created queue other');

my $two_words_queue = RT::Test->load_or_create_queue(
    Name => 'Two Words',
);
ok $two_words_queue && $two_words_queue->id, 'loaded or created a queue';


{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    my $active = "( ".join( " OR ", map "Status = '$_'", RT::Queue->ActiveStatusArray())." )";

    require RT::Search::Googleish;
    my $parser = RT::Search::Googleish->new(
        TicketsObj => $tickets,
        Argument   => '',
    );
    is $parser->QueryToSQL("foo"), "$active AND ( Subject LIKE 'foo' )", "correct parsing";
    is $parser->QueryToSQL("1"), "( Id = 1 )", "correct parsing";
    is $parser->QueryToSQL("#1"), "( Id = 1 )", "correct parsing";
    is $parser->QueryToSQL("'1'"), "$active AND ( Subject LIKE '1' )", "correct parsing";

    is $parser->QueryToSQL("foo bar"),
        "$active AND ( Subject LIKE 'foo' AND Subject LIKE 'bar' )",
        "correct parsing";
    is $parser->QueryToSQL("'foo bar'"),
        "$active AND ( Subject LIKE 'foo bar' )",
        "correct parsing";

    is $parser->QueryToSQL("'foo \\' bar'"),
        "$active AND ( Subject LIKE 'foo \\' bar' )",
        "correct parsing";
    is $parser->QueryToSQL('"foo \' bar"'),
        "$active AND ( Subject LIKE 'foo \\' bar' )",
        "correct parsing";
    is $parser->QueryToSQL('"\f\o\o"'),
        "$active AND ( Subject LIKE '\\\\f\\\\o\\\\o' )",
        "correct parsing";

    is $parser->QueryToSQL("General"), "( Queue = 'General' ) AND $active", "correct parsing";
    is $parser->QueryToSQL("'Two Words'"), "( Queue = 'Two Words' ) AND $active", "correct parsing";
    is $parser->QueryToSQL("subject:'Two Words'"), "$active AND ( Subject LIKE 'Two Words' )", "correct parsing";

    is $parser->QueryToSQL("me"), "( Owner.id = '__CurrentUser__' ) AND $active", "correct parsing";
    is $parser->QueryToSQL("'me'"), "$active AND ( Subject LIKE 'me' )", "correct parsing";
    is $parser->QueryToSQL("owner:me"), "( Owner.id = '__CurrentUser__' ) AND $active", "correct parsing";
    is $parser->QueryToSQL("owner:'me'"), "( Owner = 'me' ) AND $active", "correct parsing";
}

my $ticket_found_1 = RT::Ticket->new($RT::SystemUser);
my $ticket_found_2 = RT::Ticket->new($RT::SystemUser);
my $ticket_not_found = RT::Ticket->new($RT::SystemUser);

$ticket_found_1->Create(
    Subject   => 'base ticket 1'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 1',
);
ok( $ticket_found_1->id, 'created ticket for custom search');


$ticket_found_2->Create(
    Subject   => 'base ticket 2'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 2',
);
ok( $ticket_found_2->id, 'created ticket for custom search');

$ticket_not_found = RT::Ticket->new($RT::SystemUser);
$ticket_not_found->Create(
    Subject   => 'not found subject' . $$,
    Queue     => 'other',
    Owner     => 'nobody',
    Requestor => 'notfound@localhost',
    Content   => 'this is not found content',
);
ok( $ticket_not_found->id, 'created ticket for custom search');

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
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
}

$ticket_not_found->SetStatus('open');
is( $ticket_not_found->Status, 'open', 'status of not found ticket is open' );
@queries = qw/new status:new/;
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
}

@queries = ( 'fulltext:"base ticket 1"', "'base ticket 1'" );
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_lacks( 'base ticket 2',     'base ticket 2 is not found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
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



    my $ticket_quote = RT::Ticket->new($RT::SystemUser);
    $ticket_quote->Create(
        Subject   => qq!base${quote}ticket $$!,
        Queue     => 'general',
        Owner     => $user->Name,
        Requestor => qq!custom${quote}search\@localhost!,
        Content   => qq!this is base${quote}ticket with quote inside!,
    );
    ok( $ticket_quote->id, 'created ticket with quote for custom search' );

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
        my $escape_quote = $quote;
        RT::Interface::Web::EscapeUTF8(\$escape_quote);
        $m->content_contains( "base${escape_quote}ticket",
            "base${quote}ticket is found" );
    }
}
