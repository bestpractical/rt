use strict;
use warnings;
use Test::More;
use File::Find;
use HTTP::Status qw();

BEGIN {
    $ENV{RT_TEST_DEVEL} ||= 1;
    sub wanted {
        -f && /\.html$/ && $_ !~ /Logout.html$/ && $File::Find::dir !~ /RichText/;
    }
    my $tests = 7;
    find( sub { wanted() and $tests += 3 }, 'share/html/' );
    plan tests => $tests + 1; # plus one for warnings check
}


use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;

my $cookie_jar = HTTP::Cookies->new;

use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;

# give the agent a place to stash the cookies
$agent->cookie_jar($cookie_jar);

# get the top page
my $url = $agent->rt_base_url;
$agent->get($url);

is($agent->status, HTTP::Status::HTTP_OK, "Loaded a page");

# follow the link marked "Login"
$agent->login(root => 'password');
is($agent->status, HTTP::Status::HTTP_OK, "Fetched the page ok");
$agent->content_contains('Logout', "Found a logout link");


find ( { wanted => sub { wanted() and test_get($agent, $File::Find::name) }, no_chdir => 1 } , 'share/html/');

# We expect to spew a lot of warnings; toss them away
$agent->get_warnings;

sub test_get {
    my $agent = shift;
        my $file = shift;

        $file =~ s#^share/html/##;
        diag( "testing $url/$file" );

        $agent->get("$url/$file");
        isnt($agent->status, HTTP::Status::HTTP_INTERNAL_SERVER_ERROR, "Loaded $file");
        $agent->content_lacks('Not logged in', "Still logged in for  $file");
        $agent->content_lacks('raw error', "Didn't get a Mason compilation error on $file") or do {
            if (my ($error) = $agent->content =~ /<pre>(.*?line.*?)$/s) {
                diag "$file: $error";
            }
        };
}

