use strict;
use warnings;

use RT::Test tests => undef, config => 'Set( $HideUnsetFieldsOnDisplay, 1 );';

my @link_classes = qw(
    DependsOn
    DependedOnBy
    MemberOf
    Members
    RefersTo
    ReferredToBy
);

my $foo = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test display page',
);
my $dep = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'dep ticket',
);
my $bar = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'depend ticket',
    Starts    => '2011-07-08 00:00:00',
    Started   => '2011-07-09 00:00:00',
    Resolved  => '2011-07-11 00:00:00',
    Due       => '2011-07-12 00:00:00',
    Cc        => 'foo@example.com',
    AdminCc   => 'admin@example.com',
    DependsOn => [ $dep->id ],
);
$bar->SetTold;

my ( $baseurl, $m ) = RT::Test->started_ok;
diag "URL is: $baseurl";

diag "test with root";
{
    $m->login;
    $m->goto_ticket( $foo->id );

    my $dom = $m->dom;

    for my $class (qw/starts started due resolved cc admincc/) {
        is $dom->find(qq{tr.$class.unset-field})->size, 1, "found unset $class";
    }

    is $dom->find(qq{tr.told:not(.unset-field)})->size, 1, "has Told as root can modify it";

    for my $class (@link_classes) {
        is $dom->find(qq{tr.$class:not(.unset-field)})->size, 1, "has $class as root can create";
    }

    $m->goto_ticket( $bar->id );
    $dom = $m->dom;
    for my $class (qw/starts started due resolved cc admincc/) {
        is $dom->find(qq{tr.$class:not(.unset-field)})->size, 1, "has $class as value is set";
    }
}

diag "test without ModifyTicket right";
{
    my $user =
      RT::Test->load_or_create_user( Name => 'foo', Password => 'password' );
    RT::Test->set_rights( Principal => $user, Right => ['ShowTicket'] );
    $m->login( 'foo', 'password', logout => 1 );
    $m->goto_ticket( $foo->id );
    my $dom = $m->dom;
    is $dom->find(qq{tr.told.unset-field})->size, 1, "lacks Told as it is unset and user has no modify right";
    for my $class ( @link_classes ) {
        is $dom->find(qq{tr.$class.unset-field})->size, 1, "lacks $class as it is unset and user has no modify right";
    }

    $m->goto_ticket( $bar->id );
    $dom = $m->dom;
    is $dom->find(qq{tr.DependsOn:not(.unset-field)})->size, 1, "has Depends on as it is set";
}

diag "Test unset custom fields";
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name        => 'TextArea',
        Type        => 'Text',
        Queue       => 0,
        LookupType  => 'RT::Queue-RT::Ticket',
    );
    ok $cf && $cf->id, "Created TextArea CF";

    $m->login( 'root', 'password', logout => 1 );
    $m->goto_ticket( $foo->id );
    my $dom = $m->dom;
    my $cfid = $cf->Id;
    is $dom->find(qq{tr.custom-field.custom-field-$cfid.unset-field})->size, 1, "found unset custom field";

    # open ticket "Basics" page
    my $EditUrl = "/Ticket/Modify.html?id=" . $foo->id;
    $m->get_ok($EditUrl, "Fetched $EditUrl");
    $m->content_contains('TextArea:');

    my $cf_input = RT::Interface::Web::GetCustomFieldInputName(
            Object      => $foo,
            CustomField => $cf,
        );

    $m->submit_form_ok({
        with_fields => {
            $cf_input            => 'some unique content',
            $cf_input . '-Magic' => "1",
        },
    }, 'submitted form to initially set CFs');

    $m->goto_ticket( $foo->id );
    $dom = $m->dom;
    $m->content_contains('some unique content');
    isnt $dom->find(qq{tr.customfield.unset-field})->size, 1, "no unset custom fields";
}

done_testing;
