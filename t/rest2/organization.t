use strict;
use warnings;
use RT::Test::REST2 tests => undef;

use_ok('RT::REST2::Util', qw(expand_uid));

diag "Test expand_uid with default RT Organization of example.com";
{
    my $base_url = RT::REST2->base_uri;

    my $uid_parts = expand_uid('RT::User-test');
    is($uid_parts->{'type'}, 'user', 'Got correct class');
    is($uid_parts->{'id'}, 'test', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/user/test', 'Got correct url');

    # User with dashes in the username
    $uid_parts = expand_uid('RT::User-test-user');
    is($uid_parts->{'type'}, 'user', 'Got correct class');
    is($uid_parts->{'id'}, 'test-user', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/user/test-user', 'Got correct url');

    $uid_parts = expand_uid('RT::CustomField-example.com-3');
    is($uid_parts->{'type'}, 'customfield', 'Got correct class');
    is($uid_parts->{'id'}, '3', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/customfield/3', 'Got correct url');
}

RT->Config->Set('Organization', 'name-with-dashes');

diag "Test expand_uid with Organization name with dashes";
{
    my $base_url = RT::REST2->base_uri;

    my $uid_parts = expand_uid('RT::User-test');
    is($uid_parts->{'type'}, 'user', 'Got correct class');
    is($uid_parts->{'id'}, 'test', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/user/test', 'Got correct url');

    # User with dashes in the username
    $uid_parts = expand_uid('RT::User-test-user');
    is($uid_parts->{'type'}, 'user', 'Got correct class');
    is($uid_parts->{'id'}, 'test-user', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/user/test-user', 'Got correct url');

    $uid_parts = expand_uid('RT::CustomField-name-with-dashes-3');
    is($uid_parts->{'type'}, 'customfield', 'Got correct class');
    is($uid_parts->{'id'}, '3', 'Got correct id');
    is($uid_parts->{'_url'}, $base_url . '/customfield/3', 'Got correct url');
}

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $queue_url;
# search Name = General
{
    my $res = $mech->post_json("$rest_base_path/queues",
        [{ field => 'Name', value => 'General' }],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 1);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 1);
    is(scalar @{$content->{items}}, 1);

    my $queue = $content->{items}->[0];
    is($queue->{type}, 'queue');
    is($queue->{id}, 1);
    like($queue->{_url}, qr{$rest_base_path/queue/1$});
    $queue_url = $queue->{_url};
}

done_testing;

