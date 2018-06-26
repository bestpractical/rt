use strict;
use warnings;

use RT::Test tests => undef;
use HTML::Entities qw/decode_entities/;

my ($baseurl, $m) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

my $root = RT::Test->load_or_create_user( Name => 'root' );
my ($ok) = $root->SetSignature("Signature one\nSignature two\n");
ok($ok, "Set signature");

my $t = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Signature quoting',
    Content => "First\nSecond\nThird\n",
);

my $initial = $t->Transactions->First->id;

sub template_is {
    my (%args) = (
        HTML        => 0,
        Quote       => 0,
        BeforeQuote => 0,
    );
    my $expected = pop(@_);
    $args{$_}++ for @_;

    my $prefs = $root->Preferences($RT::System);
    $prefs->{SignatureAboveQuote} = $args{BeforeQuote};
    $prefs->{MessageBoxRichText}  = $args{HTML};
    ($ok) = $root->SetPreferences($RT::System, $prefs);
    ok($ok, "Preferences updated");

    my $url = "/Ticket/Update.html?id=" . $t->id;
    $url .= "&QuoteTransaction=$initial" if $args{Quote};
    $m->get_ok($url);

    $m->form_name('TicketUpdate');
    my $value = $m->value("UpdateContent");

    # Work around a bug in Mechanize, wherein it thinks newlines
    # following textareas are significant -- browsers do not.
    $value =~ s/^\n//;

    # For ease of interpretation, replace blank lines with dots, and
    # put a $ after trailing whitespace.
    my $display = $value;
    $display =~ s/^$/./mg;
    $display =~ s/([ ]+)$/$1\$/mg;

    # Remove the timestamp from the quote header
    $display =~ s/On \w\w\w \w\w\w+ \d\d \d\d:\d\d:\d\d \d\d\d\d, \w+ wrote:/Someone wrote:/;

    is($display, $expected, "Content matches expected");

    my $trim = RT::Interface::Web::StripContent(
        CurrentUser    => RT::CurrentUser->new($root),
        Content        => $value,
        ContentType    => $args{HTML} ? "text/html" : "text/plain",
        StripSignature => 1,
    );
    if ($args{Quote}) {
        ok($trim, "Counts as not empty");
    } else {
        is($trim, '', "Counts as empty");
    }
}


### Text

subtest "Non-HTML, no reply" => sub {
    template_is(<<'EOT') };
.
.
-- $
Signature one
Signature two
EOT


subtest "Non-HTML, no reply, before quote (which is irrelevant)" => sub {
    template_is(qw/BeforeQuote/, <<'EOT') };
.
.
-- $
Signature one
Signature two
EOT

subtest "Non-HTML, reply" => sub {
    template_is(qw/Quote/, <<'EOT') };
Someone wrote:
> First
> Second
> Third
.
.
.
-- $
Signature one
Signature two
EOT

subtest "Non-HTML, reply, before quote" => sub {
    template_is(qw/Quote BeforeQuote/, <<'EOT') };
.
.
-- $
Signature one
Signature two
.
Someone wrote:
> First
> Second
> Third
EOT



### HTML

my $quote = '<div class="gmail_quote">Someone wrote:<br />'
    .'<blockquote class="gmail_quote" type="cite">'
    .'<pre style="white-space: pre-wrap; font-family: monospace;">'
    ."First\nSecond\nThird\n"
    .'</pre></blockquote></div>';

subtest "HTML, no reply" => sub {
    template_is(
        qw/HTML/,
        '<br /><p>--&nbsp;<br />Signature one<br />Signature two</p>',
    ) };

subtest "HTML, no reply, before quote (which is irrelevant)" => sub {
    template_is(
        qw/HTML BeforeQuote/,
        '<br /><p>--&nbsp;<br />Signature one<br />Signature two</p>',
    ) };

subtest "HTML, reply" => sub {
    template_is(
        qw/HTML Quote/,
        $quote.'<br /><p>--&nbsp;<br />Signature one<br />Signature two</p>',
    ) };

subtest "HTML, reply, before quote" => sub {
    template_is(
        qw/HTML Quote BeforeQuote/,
        '<br /><p>--&nbsp;<br />Signature one<br />Signature two</p>'
            . "<br />" . $quote,
    ) };


done_testing;
