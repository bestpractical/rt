use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

use Data::Dumper;
my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;

my $rest_base_path = '/REST/2.0';

my $test_user = RT::Test::REST2->user;
$test_user->PrincipalObj->GrantRight(Right => 'SuperUser');

diag "Test searching groups based on custom field value";
{
    my $group1 = RT::Group->new(RT->SystemUser);
    $group1->CreateUserDefinedGroup(Name => 'Group 1');

    my $group2 = RT::Group->new(RT->SystemUser);
    $group2->CreateUserDefinedGroup(Name => 'Group 2');

    my $cf = RT::CustomField->new(RT->SystemUser);
    ok($cf, "Have a CustomField object");

    my ($id, $msg) =  $cf->Create(
        Name        => 'Group Type',
        Description => 'A Testing custom field',
        Type        => 'Freeform',
        MaxValues   => 1,
        LookupType  => RT::Group->CustomFieldLookupType,
    );
    ok($id, 'Group custom field correctly created');
    ok($cf->AddToObject( RT::Group->new( RT->SystemUser ) ), 'applied Testing CF globally');

    (my $ret, $msg) = $group1->AddCustomFieldValue( Field => 'Group Type', Value => 'Test' );
    ok ($ret, "Added Group Type custom field value 'Test' to group1");

    my $payload = [
        {
            "field" => "CustomField.{Group Type}",
            "value"       => "Test",
        }
    ];

    my $res = $mech->post_json("$rest_base_path/groups",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    ok( $content->{'count'} eq 1, "Found one group" );
    ok( $content->{'items'}[0]->{'id'} eq $group1->Id, "Found group1 group" );
}
$test_user->PrincipalObj->RevokeRight( Right => 'SuperUser' );

done_testing();
