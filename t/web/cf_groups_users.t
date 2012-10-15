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

foreach my $name ( map { @$_ } values %{ RT->Config->Get('CustomFieldGroupings')->{'RT::User'} } ) {
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $cf->Create(
        Name => $name,
        Description => 'A custom field',
        LookupType => RT::User->new( $RT::SystemUser )->CustomFieldLookupType,
        Type => 'FreeformSingle',
        Pattern => qr{^(?!bad value).*$},
    );
    ok $id, "custom field '$name' correctly created";

    ($id, $msg) = $cf->AddToObject( RT::User->new( $cf->CurrentUser ) );
    ok $id, "applied custom field" or diag "error: $msg";

    $CF{$name} = $cf;
}

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $index = 1;

{
    note "testing Create";
    $m->follow_link_ok({id => 'tools-config-users-create'}, 'Create ');

    my $dom = $m->dom;
    $m->form_name('UserCreate');

    $m->field( 'Name', 'user'. $index++ );

    my $prefix = 'Object-RT::User--CustomField-';
    my $input_name = $prefix . $CF{'TestIdentity'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.user-info-identity input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestIdentityValue' );

    $input_name = $prefix . $CF{'TestAccessControl'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.user-info-access-control input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestAccessControlValue' );

    $input_name = $prefix . $CF{'TestLocation'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.user-info-location input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestLocationValue' );

    $input_name = $prefix . $CF{'TestPhones'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.user-info-phones input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestPhonesValue' );

    $input_name = $prefix . $CF{'TestMore'}->id .'-Value';
    is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
    ok $dom->at(qq{.user-info-cfs input[name="$input_name"]}), "CF is in the right place";
    $m->field( $input_name, 'TestMoreValue' );

    $m->submit;
    $m->content_like(qr{User created});
    my ($id) = ($m->uri =~ /id=(\d+)/);
    ok $id, "found user's id #$id";

    note "testing values on Modify page and on the object";
    {
        my $user = RT::User->new( RT->SystemUser );
        $user->Load( $id );
        ok $user->id, "loaded user";

        $m->form_name('UserModify');
        foreach my $cf_name ( keys %CF ) {
            is $user->FirstCustomFieldValue($cf_name), "${cf_name}Value",
                "correct value of $cf_name CF";
            my $input = 'Object-RT::User-'. $id .'-CustomField-'
                . $CF{$cf_name}->id .'-Value';
            is $m->value($input), "${cf_name}Value",
                "correct value in UI";
            $m->field( $input, "${cf_name}Changed" );
        }
        $m->submit;
    }

    note "testing that update works";
    {
        my $user = RT::User->new( RT->SystemUser );
        $user->Load( $id );
        ok $user->id, "loaded user";

        $m->form_name('UserModify');
        foreach my $cf_name ( keys %CF ) {
            is $user->FirstCustomFieldValue($cf_name), "${cf_name}Changed",
                "correct value of $cf_name CF";
            my $input = 'Object-RT::User-'. $id .'-CustomField-'
                . $CF{$cf_name}->id .'-Value';
            is $m->value($input), "${cf_name}Changed",
                "correct value in UI";
        }
    }
}

undef $m;
done_testing;
