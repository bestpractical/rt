use strict;
use warnings;

BEGIN { $ENV{RT_TEST_WEB_HANDLER} = 'inline' }

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $message = RT->System->UserMessages->{'SQLTimeout'};
ok( $message, 'loaded the SQLTimeout user message' );

# RT::Handle::SimpleQuery stashes this note when the database refuses to run a
# query. There is no portable way to make a query time out from a test, so set
# the note the same way SimpleQuery does.
our $StashUserMessage = 0;
{
    my $simple_query = \&RT::Handle::SimpleQuery;
    no warnings 'redefine';
    *RT::Handle::SimpleQuery = sub {
        my $self = shift;
        my $ret  = $simple_query->( $self, @_ );
        if ( $StashUserMessage && $HTML::Mason::Commands::m ) {
            $HTML::Mason::Commands::m->notes( 'Message:SQLTimeout' => 1 );
        }
        return $ret;
    };
}

diag "Full page loads hand user messages to the page for growl";
{
    local $StashUserMessage = 1;
    $m->get_ok( $baseurl . '/index.html' );

    my ($user_messages) = $m->content =~ /RT\.UserMessages = (\{.*?\});/;
    ok( $user_messages, 'index.html wrote RT.UserMessages to the page' );
    is_deeply(
        JSON::from_json($user_messages),
        { SQLTimeout => $message },
        'RT.UserMessages holds the SQLTimeout message'
    );

    ok( !$m->response->header('HX-Trigger'), 'no HX-Trigger on a full page load' );
}

diag "htmx component requests send user messages in HX-Trigger instead";
{
    local $StashUserMessage = 1;
    $m->add_header( 'HX-Request' => 'true' );
    $m->get_ok( $baseurl . '/Views/Component/QuickCreate' );

    my $trigger = $m->response->header('HX-Trigger');
    ok( $trigger, 'component request set an HX-Trigger header' );
    is_deeply(
        JSON::from_json( $trigger || '{}' )->{'userWarnings'},
        [$message],
        'HX-Trigger carries the SQLTimeout message as a user warning'
    );

    unlike( $m->content, qr/RT\.UserMessages/, 'component response has no footer to write RT.UserMessages' );

    $m->delete_header('HX-Request');
}

diag "htmx requests for a full page still use the footer, and do not double up";
{
    local $StashUserMessage = 1;
    $m->add_header( 'HX-Request' => 'true' );
    $m->get_ok( $baseurl . '/index.html' );

    my ($user_messages) = $m->content =~ /RT\.UserMessages = (\{.*?\});/;
    is_deeply(
        JSON::from_json($user_messages),
        { SQLTimeout => $message },
        'RT.UserMessages holds the SQLTimeout message'
    );

    my $trigger = $m->response->header('HX-Trigger') || '{}';
    ok( !JSON::from_json($trigger)->{'userWarnings'}, 'message is not repeated in HX-Trigger' );

    $m->delete_header('HX-Request');
}

diag "Component requests with nothing stashed send no user warnings";
{
    $m->add_header( 'HX-Request' => 'true' );
    $m->get_ok( $baseurl . '/Views/Component/QuickCreate' );

    my $trigger = $m->response->header('HX-Trigger') || '{}';
    ok( !JSON::from_json($trigger)->{'userWarnings'}, 'no user warnings when no message was stashed' );

    $m->delete_header('HX-Request');
}

done_testing;
