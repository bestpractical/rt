use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( 'CustomFieldGroupings',
    'RT::User' => {
        Identity         => ['TestIdentity'],
        'Access control' => ['TestAccessControl'],
        Location         => ['TestLocation'],
        Phones           => ['TestPhones'],
        More             => ['TestMore'],
    },
);

my %CF;

while (my ($group,$cfs) = each %{ RT->Config->Get('CustomFieldGroupings')->{'RT::User'} } ) {
    my $name = $cfs->[0];
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $cf->Create(
        Name => $name,
        Description => 'A custom field',
        LookupType => RT::User->new( $RT::SystemUser )->CustomFieldLookupType,
        Type => 'FreeformSingle',
        Pattern => '^(?!bad value).*$',
    );
    ok $id, "custom field '$name' correctly created";

    ($id, $msg) = $cf->AddToObject( RT::User->new( $cf->CurrentUser ) );
    ok $id, "applied custom field" or diag "error: $msg";

    $group =~ s/\W//g;
    $CF{$name} = "$group-" . $cf->Id;
}

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my %location = (
    Identity      => ".user-info-identity",
    AccessControl => ".user-info-access-control",
    Location      => ".user-info-location",
    Phones        => ".user-info-phones",
    More          => ".user-info-cfs",
);
{
    note "testing Create";
    $m->follow_link_ok({id => 'admin-users-create'}, 'Create ');

    my $dom = $m->dom;
    $m->form_name('UserCreate');

    $m->field( 'Name', 'user1' );

    my $prefix = 'Object-RT::User--CustomField:';
    for my $name (keys %location) {
        my $input_name = $prefix . $CF{"Test$name"} .'-Value';
        is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
        ok $dom->at(qq{$location{$name} input[name="$input_name"]}), "CF is in the right place";
        $m->field( $input_name, "Test${name}Value" );
    }

    $m->submit;
    $m->content_like(qr{User created});
}

my ($id) = ($m->uri =~ /id=(\d+)/);
ok $id, "found user's id #$id";

{
    note "testing values on Modify page and on the object";
    my $user = RT::User->new( RT->SystemUser );
    $user->Load( $id );
    ok $user->id, "loaded user";

    my $dom = $m->dom;
    $m->form_name('UserModify');
    my $prefix = "Object-RT::User-$id-CustomField:";
    foreach my $name ( keys %location ) {
        is $user->FirstCustomFieldValue("Test$name"), "Test${name}Value",
            "correct value of Test$name CF";
        my $input_name = $prefix . $CF{"Test$name"} .'-Value';
        is $m->value($input_name), "Test${name}Value",
            "correct value in UI";
        $m->field( $input_name, "Test${name}Changed" );
        ok $dom->at(qq{$location{$name} input[name="$input_name"]}), "CF is in the right place";
    }
    $m->submit;
}

{
    note "testing that update works";
    my $user = RT::User->new( RT->SystemUser );
    $user->Load( $id );
    ok $user->id, "loaded user";

    $m->form_name('UserModify');
    my $prefix = "Object-RT::User-$id-CustomField:";
    foreach my $name ( keys %location ) {
        is $user->FirstCustomFieldValue("Test$name"), "Test${name}Changed",
            "correct value of Test$name CF";
        my $input = $prefix . $CF{"Test$name"} .'-Value';
        is $m->value($input), "Test${name}Changed",
            "correct value in UI";
    }
}

done_testing;
