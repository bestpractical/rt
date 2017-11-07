use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket(
    Subject => 'test ticket basics',
    Queue   => 1,
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

my $root = RT::Test->load_or_create_user( Name => 'root' );

# Failing test where the time units are not preserved when you
# click 'Add more files' on Display
my @form_tries = (
    {Subject => "hello rt"},
    {Status  => "open"},
    {Owner   => $root->id},

    (
        map +{
            "Time$_"           => undef,
            "Time$_-TimeUnits" => 'hours',
        }, qw/Estimated Worked Left/
    ),
    (
        map +{
            "Time$_"           => '1',
            "Time$_-TimeUnits" => 'hours',
        }, qw/Estimated Worked Left/
    ),

    {InitialPriority      => "10"},
    {FinalPriority => "10"},
);

for my $try (@form_tries) {
    $m->goto_create_ticket(1);
    $m->form_name('TicketCreate');
    $m->set_fields(%$try);
    $m->click('AddMoreAttach');
    $m->form_name('TicketCreate');
    for my $field (keys %$try) {
        is(
            $m->value($field),
            defined($try->{$field}) ? $try->{$field} : '',
            "field $field is the same after the form was submitted"
        );
    }
}

# Test for time unit preservation in Jumbo
for my $try (@form_tries) {
    my $jumbo_ticket = RT::Test->create_ticket(
        Subject => 'test jumbo ticket basics',
        Queue   => 1,
    );

    local($try->{Priority}) = delete local($try->{InitialPriority})
        if exists $try->{InitialPriority};

    $m->get( $url . "/Ticket/ModifyAll.html?id=" . $jumbo_ticket->id );
    $m->form_name('TicketModifyAll');
    $m->set_fields(%$try);
    $m->click('AddMoreAttach');
    $m->form_name('TicketModifyAll');
    for my $field (keys %$try) {
        is(
            $m->value($field),
            defined($try->{$field}) ? $try->{$field} : '',
            "field $field is the same after the Jumbo form was submitted"
        );
    }
}

my $cf = RT::Test->load_or_create_custom_field(
    Name       => 'CF1',
    Type       => 'Freeform',
    Pattern    => '.', # mandatory
    Queue      => 'General',
);

# More time unit testing by a failing CF validation
$m->get_ok($url.'/Admin/CustomFields/Objects.html?id='.$cf->id);
$m->form_with_fields('UpdateObjs');
$m->tick('AddCustomField-'.$cf->id => '0'); # Make CF global
$m->click('UpdateObjs');
$m->text_contains("Globally added custom field CF1", 'CF applied globally');

# Test for preservation when a ticket is submitted and CF validation fails
for my $try (@form_tries) {
    $m->goto_create_ticket(1);
    $m->form_name('TicketCreate');
    $m->set_fields(%$try);
    $m->submit();
    $m->form_name('TicketCreate');
    for my $field (keys %$try) {
        is(
            $m->value($field),
            defined($try->{$field}) ? $try->{$field} : '',
            "field $field is the same after the form was submitted"
        );
    }
}

done_testing();
