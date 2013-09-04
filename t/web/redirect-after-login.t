
use strict;
use warnings;

use RT::Test tests => 122;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;
diag $url if $ENV{TEST_VERBOSE};

# test a login from the main page
{
    $agent->get_ok($url);
    is($agent->{'status'}, 200, "Loaded a page");
    is($agent->uri, $url, "didn't redirect to /NoAuth/Login.html for base URL");
    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");

    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'password' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");
    ok( $agent->content =~ /Logout/i, "Found a logout link");
    is( $agent->uri, $url, "right URL" );
    like( $agent->{redirected_uri}, qr{/NoAuth/Login\.html$}, "We redirected from login");
    $agent->logout();
}

# test a bogus login from the main page
{
    $agent->get_ok($url);
    is($agent->{'status'}, 200, "Loaded a page");
    is($agent->uri, $url, "didn't redirect to /NoAuth/Login.html for base URL");
    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");

    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'wrongpass' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");

    ok( $agent->content =~ /Your username or password is incorrect/i, "Found the error message");
    like( $agent->uri, qr{/NoAuth/Login\.html$}, "now on /NoAuth/Login.html" );
    $agent->warning_like(qr/FAILED LOGIN for root/, "got failed login warning");

    $agent->logout();
}

# test a login from a non-front page, both with a double leading slash and without
for my $path (qw(Prefs/Other.html /Prefs/Other.html)) {
    my $requested = $url.$path;
    $agent->get_ok($requested);
    is($agent->status, 200, "Loaded a page");
    like($agent->uri, qr'/NoAuth/Login\.html\?next=[a-z0-9]{32}', "on login page, with next page hash");
    is($agent->{redirected_uri}, $requested, "redirected from our requested page");

    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    ok($agent->current_form->find_input('next'));
    like($agent->value('next'), qr/^[a-z0-9]{32}$/i, "next page argument is a hash");
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");

    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'password' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");
    ok( $agent->content =~ /Logout/i, "Found a logout link");

    if ($path =~ m{/}) {
        (my $collapsed = $path) =~ s{^/}{};
        is( $agent->uri, $url.$collapsed, "right URL, with leading slashes in path collapsed" );
    } else {
        is( $agent->uri, $requested, "right URL" );
    }

    like( $agent->{redirected_uri}, qr{/NoAuth/Login\.html}, "We redirected from login");
    $agent->logout();
}

# test a bogus login from a non-front page
{
    my $requested = $url.'Prefs/Other.html';
    $agent->get_ok($requested);
    is($agent->status, 200, "Loaded a page");
    like($agent->uri, qr'/NoAuth/Login\.html\?next=[a-z0-9]{32}', "on login page, with next page hash");
    is($agent->{redirected_uri}, $requested, "redirected from our requested page");

    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    ok($agent->current_form->find_input('next'));
    like($agent->value('next'), qr/^[a-z0-9]{32}$/i, "next page argument is a hash");
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");

    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'wrongpass' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");

    ok( $agent->content =~ /Your username or password is incorrect/i, "Found the error message");
    like( $agent->uri, qr{/NoAuth/Login\.html$}, "still on /NoAuth/Login.html" );
    $agent->warning_like(qr/FAILED LOGIN for root/, "got failed login warning");

    # try to login again
    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    ok($agent->current_form->find_input('next'));
    like($agent->value('next'), qr/^[a-z0-9]{32}$/i, "next page argument is a hash");
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");

    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'password' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");

    # check out where we got to
    is( $agent->uri, $requested, "right URL" );
    like( $agent->{redirected_uri}, qr{/NoAuth/Login\.html}, "We redirected from login");
    $agent->logout();
}

# test a login from the main page with query params
{
    my $requested = $url."?user=root;pass=password";
    $agent->get_ok($requested);
    is($agent->{'status'}, 200, "Loaded a page");
    is($agent->uri, $requested, "didn't redirect to /NoAuth/Login.html for base URL");
    ok($agent->content =~ /Logout/i, "Found a logout link - we're logged in");
    $agent->logout();
}

# test a bogus login from the main page with query params
{
    my $requested = $url."?user=root;pass=wrongpass";
    $agent->get_ok($requested);
    is($agent->{'status'}, 200, "Loaded a page");
    is($agent->uri, $requested, "didn't redirect to /NoAuth/Login.html for base URL");
    
    ok($agent->content =~ /Your username or password is incorrect/i, "Found the error message");
    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");
    $agent->warning_like(qr/FAILED LOGIN for root/, "got failed login warning");
}

# test a bogus login from a non-front page with query params
{
    my $requested = $url."Prefs/Other.html?user=root;pass=wrongpass";
    $agent->get_ok($requested);
    is($agent->status, 200, "Loaded a page");
    like($agent->uri, qr'/NoAuth/Login\.html\?next=[a-z0-9]{32}', "on login page, with next page hash");
    is($agent->{redirected_uri}, $requested, "redirected from our requested page");
    ok( $agent->content =~ /Your username or password is incorrect/i, "Found the error message");

    ok($agent->current_form->find_input('user'));
    ok($agent->current_form->find_input('pass'));
    ok($agent->current_form->find_input('next'));
    like($agent->value('next'), qr/^[a-z0-9]{32}$/i, "next page argument is a hash");
    like($agent->current_form->action, qr{/NoAuth/Login\.html$}, "login form action is correct");
    $agent->warning_like(qr/FAILED LOGIN for root/, "got failed login warning");

    # Try to login again
    ok($agent->content =~ /username:/i);
    $agent->field( 'user' => 'root' );
    $agent->field( 'pass' => 'password' );

    # the field isn't named, so we have to click link 0
    $agent->click(0);
    is( $agent->status, 200, "Fetched the page ok");

    # check out where we got to
    is( $agent->uri, $requested, "right URL" );
    like( $agent->{redirected_uri}, qr{/NoAuth/Login\.html}, "We redirected from login");
    $agent->logout();
}

# test REST login response
{
    $agent = RT::Test::Web->new;
    my $requested = $url."REST/1.0/?user=root;pass=password";
    $agent->get($requested);
    is($agent->status, 200, "Loaded a page");
    is($agent->uri, $requested, "didn't redirect to /NoAuth/Login.html for REST");
    $agent->get_ok($url."REST/1.0");
}

# test REST login response for wrong pass
{
    $agent = RT::Test::Web->new;
    my $requested = $url."REST/1.0/?user=root;pass=passwrong";
    $agent->get_ok($requested);
    is($agent->status, 200, "Loaded a page");
    is($agent->uri, $requested, "didn't redirect to /NoAuth/Login.html for REST");
    like($agent->content, qr/401 Credentials required/i, "got error status");
    like($agent->content, qr/Your username or password is incorrect/, "got error message");
    $agent->warning_like(qr/FAILED LOGIN for root/, "got failed login warning");
}

# test REST login response for no creds
{
    $agent = RT::Test::Web->new;
    my $requested = $url."REST/1.0/";
    $agent->get_ok($requested);
    is($agent->status, 200, "Loaded a page");
    is($agent->uri, $requested, "didn't redirect to /NoAuth/Login.html for REST");
    like($agent->content, qr/401 Credentials required/i, "got error status");
    unlike($agent->content, qr/Your username or password is incorrect/, "didn't get any error message");
}

# XXX TODO: we should also be testing WebRemoteUserAuth here, but we don't have
# the framework for dealing with that

1;
