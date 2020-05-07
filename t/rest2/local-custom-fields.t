use strict;
use warnings;
use lib 't/lib';
use RT::Extension::REST2::Test tests => undef;

my $mech = RT::Extension::REST2::Test->mech;
my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;
$user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Load('General');
my $queue_id = $queue->id;

my $attached_single_cf = RT::CustomField->new(RT->SystemUser);
$attached_single_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Freeform CF', Type => 'Freeform', MaxValues => 1, Queue => 'General');
my $attached_single_cf_id = $attached_single_cf->id;

my $attached_multiple_cf = RT::CustomField->new(RT->SystemUser);
$attached_multiple_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Freeform CF', Type => 'Freeform', MaxValues => 0, Queue => 'General');
my $attached_multiple_cf_id = $attached_multiple_cf->id;

my $detached_cf = RT::CustomField->new(RT->SystemUser);
$detached_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Freeform CF', Type => 'Freeform', MaxValues => 1);
my $detached_cf_id = $detached_cf->id;

my $queue_cf = RT::CustomField->new(RT->SystemUser);
$queue_cf->Create(LookupType => 'RT::Queue', Name => 'Freeform CF', Type => 'Freeform', MaxValues => 1);
$queue_cf->AddToObject($queue);
my $queue_cf_id = $queue_cf->id;

# All tickets customfields
{
    my $res = $mech->post_json("$rest_base_path/customfields",
        [{field => 'LookupType', value => 'RT::Queue-RT::Ticket'}],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 3);
    is($content->{count}, 3);
    is(scalar @{$content->{items}}, 3);
    my @ids = sort map {$_->{id}} @{$content->{items}};
    is_deeply(\@ids, [$attached_single_cf_id, $attached_multiple_cf_id, $detached_cf_id]);
}

# All tickets single customfields attached to queue 'General'
{
    my $res = $mech->post_json("$rest_base_path/queue/$queue_id/customfields",
        [
            {field => 'LookupType', value => 'RT::Queue-RT::Ticket'},
            {field => 'MaxValues', value => 1},
        ],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 1);
    is($content->{count}, 1);
    is(scalar @{$content->{items}}, 1);
    is($content->{items}->[0]->{id}, $attached_single_cf_id);
}

# All single customfields attached to queue 'General'
{
    my $res = $mech->post_json("$rest_base_path/queue/$queue_id/customfields",
        [
            {field => 'MaxValues', value => 1},
        ],
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{total}, 2);
    is($content->{count}, 2);
    is(scalar @{$content->{items}}, 2);
    my @ids = sort map {$_->{id}} @{$content->{items}};
    is_deeply(\@ids, [$attached_single_cf_id, $queue_cf_id]);
}

done_testing;
