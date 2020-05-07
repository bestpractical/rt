use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $alpha = RT::Test->load_or_create_queue( Name => 'Alpha', Description => 'Queue for test' );
my $beta  = RT::Test->load_or_create_queue( Name => 'Beta', Description => 'Queue for test' );
my $bravo = RT::Test->load_or_create_queue( Name => 'Bravo', Description => 'Queue to test sorted search' );
$user->PrincipalObj->GrantRight( Right => 'SuperUser' );

my $alpha_id = $alpha->Id;
my $beta_id  = $beta->Id;
my $bravo_id = $bravo->Id;

# without disabled
{
    my $res = $mech->get("$rest_base_path/queues/all",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 4);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 4);
    is(scalar @{$content->{items}}, 4);
}

# Find disabled
{
    $alpha->SetDisabled(1);
    my $res = $mech->get("$rest_base_path/queues/all",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{count}, 3);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 3);
    is(scalar @{$content->{items}}, 3);

    $res = $mech->get("$rest_base_path/queues/all?find_disabled_rows=1",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{count}, 5);
    is($content->{page}, 1);
    is($content->{per_page}, 20);
    is($content->{total}, 5);
    is(scalar @{$content->{items}}, 5);

}

done_testing;
